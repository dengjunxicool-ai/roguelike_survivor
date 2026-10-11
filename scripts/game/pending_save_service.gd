## 应用生命周期的失败补存队列；独立 journal 可写时支持退出后恢复。
## receipt 与主存档原子提交，即使 journal 清理失败也不会重复发放。
extends Node

signal status_changed

const JOURNAL_PATH: String = "user://pending_rewards.cfg"
var _pending: Dictionary = {}
var _journal_durable: bool = true
var _journal_readable: bool = true
var _retry_seconds: float = 0.0
var _completed_souls: Dictionary = {}
var _first_save_staged_ids: Array[String] = []
var _first_save_stage_hash: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	var config := ConfigFile.new()
	var error: int = config.load(JOURNAL_PATH)
	_journal_readable = error == OK or (error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(JOURNAL_PATH))
	if error == OK:
		var entries: Variant = config.get_value("pending", "entries", {})
		if entries is Dictionary:
			_pending = entries
			_first_save_stage_hash = String(config.get_value("pending", "first_save_temp_sha256", ""))
		else:
			_journal_readable = false
	_journal_durable = _journal_readable
	_recover_staged_first_save()
	discard_previous_epoch()
	call_deferred("retry_pending")

func _process(delta: float) -> void:
	_retry_seconds += delta
	if _retry_seconds >= 1.0:
		_retry_seconds = 0.0
		if not _pending.is_empty() or not _journal_durable or not _journal_readable:
			retry_pending()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if prepare_exit():
			get_tree().quit()

func submit_run(state: String, run_state: Dictionary, receipt_id: String) -> Dictionary:
	var entry: Dictionary = _pending.get(receipt_id, {})
	if entry.is_empty():
		var journal_ready: bool = _try_reload_journal()
		var frozen_state: Dictionary = run_state.duplicate(true)
		if journal_ready:
			frozen_state["run_sequence"] = _next_run_sequence()
		entry = {"kind": "run", "state": state, "summary": frozen_state, "epoch": SaveManager.get_progress_epoch(), "requires_existing_save": FileAccess.file_exists(SaveManager.SAVE_PATH)}
		if not journal_ready:
			entry["sequence_waiting"] = true
	var result: Dictionary = _apply(receipt_id, entry) if not bool(entry.get("sequence_waiting", false)) else {"saved": false}
	if not bool(result.get("saved", false)):
		_pending[receipt_id] = entry
		_save_journal()
	elif _pending.erase(receipt_id):
		_save_journal()
	status_changed.emit()
	return result

func award_souls(amount: int, receipt_id: String, run_id: String = "") -> void:
	var entry: Dictionary = {"kind": "souls", "amount": amount, "run_id": run_id, "epoch": SaveManager.get_progress_epoch(), "requires_existing_save": FileAccess.file_exists(SaveManager.SAVE_PATH)}
	if not bool(_apply(receipt_id, entry).get("saved", false)):
		_pending[receipt_id] = entry
		_save_journal()
	elif _pending.erase(receipt_id):
		_save_journal()
	status_changed.emit()

func _apply(receipt_id: String, entry: Dictionary) -> Dictionary:
	if String(entry.get("kind", "")) == "run":
		var run_state: Dictionary = entry["summary"].duplicate(true)
		if not run_state.has("run_sequence"):
			run_state["run_sequence"] = 0 # Earlier journals have no comparable finish order.
		return RunProgressionService.record_run_result(String(entry["state"]), run_state, receipt_id)
	var already_saved: bool = bool(SaveManager.load_value(SaveManager.SECTION_PENDING_RECEIPTS, receipt_id, false))
	var saved: bool = SaveManager.commit_soul_reward(receipt_id, int(entry["amount"]))
	if saved and not already_saved:
		var run_id: String = String(entry.get("run_id", ""))
		_completed_souls[run_id] = int(_completed_souls.get(run_id, 0)) + int(entry["amount"])
	return {"saved": saved}

func retry_pending() -> void:
	if not _try_reload_journal():
		status_changed.emit()
		return
	_recover_staged_first_save()
	var epoch: String = SaveManager.get_progress_epoch()
	# 无法读取主档不等于合法 legacy；保留 journal，等待主档恢复。
	if epoch == "":
		_save_journal()
		status_changed.emit()
		return
	for receipt_id: String in _pending.keys():
		var entry: Dictionary = _pending[receipt_id]
		if String(entry.get("epoch", "")) == "":
			entry["epoch"] = epoch
		if String(entry.get("epoch", "legacy")) != epoch or bool(_apply(receipt_id, entry).get("saved", false)):
			_pending.erase(receipt_id)
	_save_journal()
	status_changed.emit()

func discard_previous_epoch(reset_all: bool = false) -> void:
	var epoch: String = SaveManager.get_progress_epoch()
	if epoch == "" and not reset_all:
		return
	if reset_all:
		_first_save_stage_hash = ""
		_first_save_staged_ids.clear()
	for receipt_id: String in _pending.keys():
		var entry_epoch: String = String(_pending[receipt_id].get("epoch", "legacy"))
		if reset_all or (entry_epoch != "" and entry_epoch != epoch):
			_pending.erase(receipt_id)
	_completed_souls.clear()
	if not _pending.is_empty() or FileAccess.file_exists(JOURNAL_PATH):
		_save_journal()

func requires_existing_save() -> bool:
	if not _journal_readable or _first_save_stage_hash != "":
		return true
	for entry: Variant in _pending.values():
		if not entry is Dictionary or bool(entry.get("requires_existing_save", true)):
			return true
	return false

## Stage a fresh user's journal against verified temporary main bytes. A failed
## rename keeps that temporary file so startup can complete the first save.
func begin_first_save() -> bool:
	if not _try_reload_journal():
		return false
	_first_save_staged_ids.clear()
	for receipt_id: String in _pending:
		var entry: Dictionary = _pending[receipt_id]
		if not bool(entry.get("requires_existing_save", true)):
			entry["requires_existing_save"] = true
			_first_save_staged_ids.append(receipt_id)
	if _first_save_staged_ids.is_empty():
		return true
	var temporary: String = SaveManager.SAVE_PATH + ".tmp"
	if not FileAccess.file_exists(temporary):
		finish_first_save(false)
		return false
	_first_save_stage_hash = FileAccess.get_sha256(temporary)
	if _first_save_stage_hash == "":
		finish_first_save(false)
		return false
	_save_journal()
	if _journal_durable:
		return true
	finish_first_save(false)
	return false

func finish_first_save(committed: bool) -> void:
	if not committed:
		for receipt_id: String in _first_save_staged_ids:
			if _pending.has(receipt_id):
				_pending[receipt_id]["requires_existing_save"] = false
	_first_save_stage_hash = ""
	if not _first_save_staged_ids.is_empty():
		_save_journal()
	_first_save_staged_ids.clear()

func _recover_staged_first_save() -> bool:
	if _first_save_stage_hash == "":
		return true
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		var temporary: String = SaveManager.SAVE_PATH + ".tmp"
		if not FileAccess.file_exists(temporary) or FileAccess.get_sha256(temporary) != _first_save_stage_hash:
			return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(SaveManager.SAVE_PATH)) != OK:
			return false
	_first_save_stage_hash = ""
	_save_journal()
	return true

func _next_run_sequence() -> int:
	var sequence: int = int(SaveManager.load_value(SaveManager.SECTION_RUN_HISTORY, "last_run_sequence", 0))
	var last_summary: Dictionary = SaveManager.get_last_run_summary()
	sequence = maxi(sequence, int(last_summary.get("run_sequence", 0)))
	for entry: Variant in _pending.values():
		if entry is Dictionary and String(entry.get("kind", "")) == "run":
			sequence = maxi(sequence, int(entry.get("summary", {}).get("run_sequence", 0)))
	return sequence + 1

func _try_reload_journal() -> bool:
	if _journal_readable:
		return true
	var config := ConfigFile.new()
	if config.load(JOURNAL_PATH) != OK:
		return false
	var entries: Variant = config.get_value("pending", "entries", {})
	if not entries is Dictionary:
		return false
	var merged: Dictionary = entries.duplicate(true)
	for receipt_id: String in _pending:
		if not merged.has(receipt_id):
			merged[receipt_id] = _pending[receipt_id]
	_pending = merged
	_first_save_stage_hash = String(config.get_value("pending", "first_save_temp_sha256", ""))
	_journal_readable = true
	_journal_durable = merged.size() == entries.size()
	for receipt_id: String in _pending:
		var entry: Dictionary = _pending[receipt_id]
		if bool(entry.get("sequence_waiting", false)):
			entry["summary"]["run_sequence"] = _next_run_sequence()
			entry.erase("sequence_waiting")
			_journal_durable = false
	return true

func _save_journal() -> void:
	if not _try_reload_journal():
		_journal_durable = false
		return
	var config := ConfigFile.new()
	config.set_value("pending", "entries", _pending.duplicate(true))
	if _first_save_stage_hash != "":
		config.set_value("pending", "first_save_temp_sha256", _first_save_stage_hash)
	var temporary: String = JOURNAL_PATH + ".tmp"
	_journal_durable = config.save(temporary) == OK
	if _journal_durable:
		_journal_durable = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(JOURNAL_PATH)) == OK

func prepare_exit() -> bool:
	retry_pending()
	return _journal_readable and (_pending.is_empty() or _journal_durable)

func status_text() -> String:
	if not _journal_readable:
		return "存档恢复记录暂时不可读；请恢复文件访问后重试"
	if _pending.is_empty():
		return ""
	if _journal_durable:
		return "存档失败：%d 项奖励或结算待补存，已保存恢复记录" % _pending.size()
	return "存档失败：%d 项待补存仅保留在本次运行；请恢复写入后再退出" % _pending.size()

func completed_souls_for_run(run_id: String) -> int:
	return int(_completed_souls.get(run_id, 0))

## 本局已获得、尚未写入钱包的奖励；终局首次冻结时计入摘要。
func pending_souls_for_run(run_id: String) -> int:
	var total: int = 0
	for entry: Dictionary in _pending.values():
		if String(entry.get("kind", "")) == "souls" and String(entry.get("run_id", "")) == run_id:
			total += maxi(int(entry.get("amount", 0)), 0)
	return total

func completed_souls_for_other_runs(run_id: String) -> int:
	var total: int = 0
	for other_id: String in _completed_souls:
		if other_id != run_id:
			total += int(_completed_souls[other_id])
	return total
