extends RefCounted
# Shapes use world coordinates. Lines start at position and extend along direction.
static func contains(shape: Dictionary, point: Vector2) -> bool:
 var p: Vector2 = shape.get("position",Vector2.ZERO)
 var r: float = float(shape.get("radius",1.0))
 var kind: String = String(shape.get("shape","circle"))
 if kind == "circle": return p.distance_squared_to(point) <= r*r+0.001
 if kind == "cone":
  var offset: Vector2 = point-p
  return offset.length_squared() <= r*r+0.001 and (offset.length_squared()<0.001 or absf(Vector2(shape.get("direction",Vector2.RIGHT)).angle_to(offset)) <= deg_to_rad(float(shape.get("angle",60.0)))*0.5+0.00001)
 for poly: PackedVector2Array in polygons(shape):
  if Geometry2D.is_point_in_polygon(point,poly): return true
  for i: int in poly.size():
   if Geometry2D.get_closest_point_to_segment(point,poly[i],poly[(i+1)%poly.size()]).distance_squared_to(point)<0.001: return true
 return false
static func polygons(shape: Dictionary) -> Array[PackedVector2Array]:
 var out: Array[PackedVector2Array] = []
 var p: Vector2 = shape.get("position",Vector2.ZERO)
 var d: Vector2 = Vector2(shape.get("direction",Vector2.RIGHT)).normalized()
 if d == Vector2.ZERO: d = Vector2.RIGHT
 var kind: String = String(shape.get("shape","circle"))
 if kind in ["line","cross"]:
  var length: float = float(shape.get("length",100.0))
  var width: float = float(shape.get("width",10.0))
  for index: int in (2 if kind == "cross" else 1):
   var axis: Vector2 = d.rotated(index*PI*0.5)
   var n: Vector2 = axis.orthogonal()*width*0.5
   var start: Vector2 = p-axis*length*0.5 if kind == "cross" else p
   out.append(PackedVector2Array([start+n,start+axis*length+n,start+axis*length-n,start-n]))
 else:
  var poly: PackedVector2Array = PackedVector2Array()
  var r: float = float(shape.get("radius",1.0))
  var angle: float = deg_to_rad(float(shape.get("angle",60.0))) if kind == "cone" else TAU
  if kind == "cone": poly.append(p)
  for i: int in 33: poly.append(p+d.rotated(-angle*0.5+angle*i/32.0)*r)
  out.append(poly)
 return out
static func bounds(shape: Dictionary) -> Rect2:
 if String(shape.get("shape","circle")) == "circle":
  var r: float = float(shape.get("radius",1.0))
  return Rect2(Vector2(shape.get("position",Vector2.ZERO))-Vector2.ONE*r,Vector2.ONE*r*2.0)
 var box: Rect2 = Rect2(Vector2(shape.get("position",Vector2.ZERO)),Vector2.ZERO)
 for poly: PackedVector2Array in polygons(shape):
  for point: Vector2 in poly: box = box.expand(point)
 return box
static func swept(shape: Dictionary, from: Vector2, to: Vector2, clearance: float = 0.0) -> bool:
 if String(shape.get("shape","circle")) == "circle":
  var p: Vector2 = shape.get("position",Vector2.ZERO)
  return Geometry2D.get_closest_point_to_segment(p,from,to).distance_to(p) <= float(shape.get("radius",1.0))+clearance+0.00001
 if contains(shape,from) or contains(shape,to): return true
 for poly: PackedVector2Array in polygons(shape):
  for i: int in poly.size():
   var a: Vector2 = poly[i]; var b: Vector2 = poly[(i+1)%poly.size()]
   if Geometry2D.segment_intersects_segment(from,to,a,b) != null: return true
   if clearance > 0.0 and (Geometry2D.get_closest_point_to_segment(a,from,to).distance_to(a)<=clearance or Geometry2D.get_closest_point_to_segment(b,from,to).distance_to(b)<=clearance): return true
 return false
static func overlaps(a: Dictionary,b: Dictionary) -> bool:
 var ac: bool = String(a.get("shape","circle")) == "circle"
 var bc: bool = String(b.get("shape","circle")) == "circle"
 if ac and bc: return Vector2(a.position).distance_to(Vector2(b.position)) <= float(a.radius)+float(b.radius)+0.00001
 if ac or bc:
  var circle: Dictionary = a if ac else b
  var other: Dictionary = b if ac else a
  var p: Vector2 = circle.position
  if contains(other,p): return true
  for poly: PackedVector2Array in polygons(other):
   for i: int in poly.size():
    if Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()]).distance_to(p) <= float(circle.radius)+0.00001: return true
  return false
 for ap: PackedVector2Array in polygons(a):
  for bp: PackedVector2Array in polygons(b):
   if Geometry2D.is_point_in_polygon(ap[0],bp) or Geometry2D.is_point_in_polygon(bp[0],ap): return true
   for i: int in ap.size():
    for j: int in bp.size():
     if Geometry2D.segment_intersects_segment(ap[i],ap[(i+1)%ap.size()],bp[j],bp[(j+1)%bp.size()]) != null: return true
 return false

# A deterministic shared point in the intersection, used by overlap-born outputs.
static func overlap_point(a: Dictionary,b: Dictionary) -> Variant:
 var ap: Vector2=a.position;var bp: Vector2=b.position
 if contains(a,bp) and contains(b,bp): return bp
 if contains(a,ap) and contains(b,ap): return ap
 var ac: bool=String(a.get("shape","circle"))=="circle"
 var bc: bool=String(b.get("shape","circle"))=="circle"
 if ac and bc:
  var distance: float=ap.distance_to(bp)
  if distance>float(a.radius)+float(b.radius): return null
  var low: float=maxf(distance-float(b.radius),0)
  var high: float=minf(float(a.radius),distance)
  return ap+ap.direction_to(bp)*(low+high)*.5
 if ac or bc:
  var circle: Dictionary=a if ac else b
  var other: Dictionary=b if ac else a
  for poly: PackedVector2Array in polygons(other):
   for i: int in poly.size():
    var point: Vector2=Geometry2D.get_closest_point_to_segment(circle.position,poly[i],poly[(i+1)%poly.size()])
    if contains(circle,point) and contains(other,point): return point
  return null
 for poly_a: PackedVector2Array in polygons(a):
  for poly_b: PackedVector2Array in polygons(b):
   for point: Vector2 in poly_a:
    if contains(b,point): return point
   for point: Vector2 in poly_b:
    if contains(a,point): return point
   for i: int in poly_a.size():
    for j: int in poly_b.size():
     var point: Variant=Geometry2D.segment_intersects_segment(poly_a[i],poly_a[(i+1)%poly_a.size()],poly_b[j],poly_b[(j+1)%poly_b.size()])
     if point!=null: return point
 return null
