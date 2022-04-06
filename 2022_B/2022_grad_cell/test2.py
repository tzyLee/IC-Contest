def generate(A):
    N = len(A)
    c = [0] * N

    yield A[:]

    i = 0
    while i < N:
        if c[i] < i:
            if i % 2 == 0:
                A[0], A[i] = A[i], A[0]
            else:
                A[c[i]], A[i] = A[i], A[c[i]]
            yield A[:]
            c[i] += 1
            i = 0
        else:
            c[i] = 0
            i += 1


A = list(range(8))
for perm in generate(A):
    print(perm)