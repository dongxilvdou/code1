extends RefCounted
var position:=.23
var velocity:=.12
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
  safe_half=lerpf(.5,.19,clampf(elapsed/4.2,0,1))
  var drift=sin(elapsed*2.25)*.34+position*.46
  velocity+=(clampf(axis,-1,1)*2.35+drift-velocity*1.10)*step
  position=clampf(position+velocity*1.35*step,-1.0,1.0)
  progress=clampf(progress+step*(.12 if absf(position)<=safe_half else -.14),0,1)
  if progress>=1:status=1
  elif progress<=0:status=-1
