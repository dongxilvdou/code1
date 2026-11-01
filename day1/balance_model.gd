extends RefCounted
var position:=.23
var velocity:=.06
var progress:=.20
var elapsed:=0.0
var safe_half:=.5
var status:=0
var paused:=false
func advance(delta: float,axis: float) -> void:
 if paused or status!=0:return
 var left=maxf(0,delta)
 while left>0 and status==0:
  var step=minf(left,1.0/120.0);left-=step;elapsed+=step
  safe_half=lerpf(.5,.25,clampf(elapsed/8.0,0,1))
  var drift=sin(elapsed*1.35)*.19+position*.24
  velocity+=(clampf(axis,-1,1)*1.35+drift-velocity*1.45)*step
  position=clampf(position+velocity*step,-1.0,1.0)
  progress=clampf(progress+step*(.12 if absf(position)<=safe_half else -.14),0,1)
  if progress>=1:status=1
  elif progress<=0:status=-1
