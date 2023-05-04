'''
FRAC_BIT = 22;
INT_BIT = 23;

x = -2.926420;
p = [0.0001,    0.0018 ,   0.0137,    0.0547,    0.1215,   -0.0004]
p.reverse()

q_x = int(x*(2**FRAC_BIT))
print(q_x)

last = q_x
for pwr, (i, c) in enumerate(zip(range(2, 9), p), 2):
  last = last * q_x
  c = int(x*(2**FRAC_BIT))
  cx = c*int(last/(2**(FRAC_BIT*(pwr-1))))
  q_cx = int(cx/(2**(2*FRAC_BIT)))
  print(last, int(last/(2**(FRAC_BIT*pwr))), cx, q_cx)
print()
for c in p:
  print(int(c*2**FRAC_BIT))
'''

p = [0.0001,    0.0018,    0.0137,    0.0547,    0.1215,   -0.0004]
p = [-0.0001 ,  -0.0014  , -0.0107 ,  -0.0356  , -0.0096  ,  0.2475  , -0.0002]
p = [-0.0001 ,  -0.0018 ,  -0.0190  , -0.1083  , -0.3393  , -0.5084  , -0.0094  ,  1.0124   , 0.0008];
for i in p:
	print(round(i*(2**22)))

xs = [5378.897269941114, -1838.0469207909714, 628.0871921292813, -214.62646924545396, 73.34096583725301, -25.061667784273283, 8.5639340164, -2.926420, 1]
print('-'*50)

ss = []
for xx, cc in zip(reversed(xs), reversed(p)):
  pxc = xx*cc
  ss.append(pxc)
  print(pxc, round(pxc*2**22), hex(round(pxc*2**22)), [round(cc*2**22), round(xx*2**22)])


s1 = sum(ss[-5:])
s2 = sum(ss[:4]) + s1
print('-'*50)
print(s1, round(s1*2**22), hex(round(s1*2**22)))
print(s2, round(s2*2**22), hex(round(s2*2**22)))


gold = sum(ss)
print('-'*50)
print(gold, round(gold*2**22))
'''
if xs[-2] < 0:
    fgold = gold+0.5
else:
    raise ValueError
    fgold = 0.5-(gold)
print('-'*50)
print(fgold, round(fgold*2**22))'''

