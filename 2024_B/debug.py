import numpy as np
with open('ImgROM.rcf') as f:
    src = [int(i, 2) for i in f.readlines()[:10000]]

for fid in range(1, 2):
    with open("pattern{}".format(fid)) as f:
        gold1 = []
        gold2 = []
        for i, line in enumerate(f):
            if i == 0:
                continue
            words = line.split()
            if i == 1:
                h0, v0 = [int(i) for i in words[2:]]
            elif i == 2:
                sw, sh = [int(i) for i in words[2:]]
            elif i == 3:
                tw, th = [int(i) for i in words[2:]]
            elif i-4 < tw*th:
                gold1.append(int(words[0]))
            else:
                gold2.append(int(words[0]))

    print(h0, v0)
    print(sw, sh)
    print(tw, th)

    src = np.array(src).reshape((100, 100))

    gold1 = np.array(gold1).reshape((th, tw))
    gold2 = np.array(gold2).reshape((th, tw))

    srcimg = src[v0-1:v0+sh+1, h0-1:h0+sw+1]

    interp1 = np.zeros((sh+2, tw), dtype=np.int32)
    dBits = 15
    # delta = int((sw-1)/(tw-1)*2**dBits)/2**dBits
    delta = (sw-1)/(tw-1)
    for i in range(sh+2):
        k = 0
        # jdk == j*delta-k
        jdk = 0
        for j in range(tw):
            # while x > 1:
            # while k*(tw-1) < j*(sw-1):
            while jdk > 0:
                k += 1
                jdk -= 1
            # if k == j*(sw-1)//(tw-1):
            # if jdk == 0: (this is not accurate enough)
            if k*(tw-1) == j*(sw-1):
                interp1[i, j] = srcimg[i, k+1]
                # print(hex(interp1[i, j]))
                jdk += delta
                continue
            pn1 = src[v0+i-1, h0+k-2]
            p0 = src[v0+i-1, h0+k-1]
            p1 = src[v0+i-1, h0+k]
            p2 = src[v0+i-1, h0+k+1]

            a = int((-pn1/2 + p0*3/2 - p1*3/2 + p2/2)*2**8)/2**8
            # a = (-pn1/2 + p0*3/2 - p1*3/2 + p2/2)
            b = int((pn1 - p0*5/2 + p1*2 - p2/2)*(2**8))/2**8
            c = int((-pn1/2 + p1/2)*(2**8))/2**8
            d = p0

            # x = (j/(tw-1) - (k-1)/(sw-1))*(sw-1)
            # x = int((jdk+1)*(2**15))/(2**15)
            x = jdk+1
            px = np.clip(a*x**3 + b*x**2 + c*x + d, 0, 255)
            # px = np.clip(a*int(x**3*(2**14))/(2**14) + b*int(x**2*(2**14))/(2**14) + c*int(x*(2**14))/(2**14) + d, 0, 255)
            interp1[i, j] = round(px)
            jdk += delta

    # with np.printoptions(linewidth=np.inf, formatter={'int': '{:02X}'.format}):
    #     print(interp1)
    #     print()

    interp2 = np.zeros((th, tw), dtype=np.int32)
    dBits = 20
    # delta = (sh-1)/(th-1)
    delta = (sh-1)/(th-1)
    for i in range(tw):
        k = 0
        jdk = 0
        for j in range(th):
            # while k*(th-1) < j*(sh-1):
            while jdk > 0:
                k += 1
                jdk -= 1
            # if jdk == 0: (this is not accurate enough)
            if k*(th-1) == j*(sh-1):
                interp2[j, i] = interp1[k+1, i]
                jdk += delta
                print('skip idx', [j, i])
                continue
            pn1 = interp1[k-2+1, i]
            p0 = interp1[k-1+1, i]
            p1 = interp1[k+1, i]
            p2 = interp1[k+1+1, i]

            a = (-pn1/2 + p0*3/2 - p1*3/2 + p2/2)
            b = (pn1 - p0*5/2 + p1*2 - p2/2)
            c = (-pn1/2 + p1/2)
            d = p0
            print('points', [pn1, p0, p1, p2], 'idx', [j, i], 'abcd', [a,b,c,d])

            # x = (j/(th-1) - (k-1)/(sh-1))*(sh-1)
            # x = (j/(th-1)*(sh-1) - (k-1))
            # x = int((jdk+1)*(2**16))/(2**16)
            x = jdk+1
            # px = np.clip(a*int(x**3*(2**15))/(2**15) + b*int(x**2*(2**15))/(2**15) + c*int(x*(2**15))/(2**15) + d, 0, 255)
            px = np.clip(a*x**3 + b*x**2 + c*x + d, 0, 255)
            interp2[j, i] = round(px)
            jdk += delta

    with np.printoptions(linewidth=np.inf, formatter={'int': '{:02X}'.format}):
        print(interp2)
        # print((interp2 == gold1) | (interp2 == gold2))
    if (interp2 == gold1).all():
        print('pattern{} passed'.format(fid))
    else:
        print('pattern{} FAILED'.format(fid))