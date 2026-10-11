"""Author original short game SFX; deterministic noise and damped partials, no external media."""
import wave,math,random,struct
from pathlib import Path
R=Path(__file__).resolve().parents[1]/'audio/sfx';R.mkdir(parents=True,exist_ok=True)
rate=44100
for name,duration in [('dart_volley',.22),('dart_hit',.16),('shadow_cast',.65),('survivor_level',.8)]:
    rng=random.Random(827);last=0;values=[]
    for i in range(int(duration*rate)):
        t=i/rate;u=t/duration;noise=rng.uniform(-1,1);last=last*.75+noise*.25
        if name=='dart_volley':v=(noise-last)*math.sin(math.pi*u)**2*.35+math.sin(2*math.pi*(950*t-450*t*t))*.1*math.sin(math.pi*u)
        elif name=='dart_hit':v=(math.sin(2*math.pi*1170*t)+.4*math.sin(2*math.pi*1831*t))*math.exp(-t*38)*.2+noise*math.exp(-t*65)*.3
        elif name=='shadow_cast':v=(last*.30+math.sin(2*math.pi*(150*t+190*t*t))*.14+math.sin(2*math.pi*72*t)*.10)*math.sin(math.pi*u)**1.2
        else:
            v=0
            for onset,hz in [(0,523.25),(.13,659.25),(.26,783.99),(.39,1046.5)]:
                q=t-onset
                if q>=0:v+=(math.sin(2*math.pi*hz*q)+.2*math.sin(4*math.pi*hz*q))*math.exp(-q*6)*min(1,q*120)*.12
        values.append(struct.pack('<h',int(max(-.95,min(.95,v))*32767)))
    with wave.open(str(R/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(values))
