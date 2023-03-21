data = """11 25 53 41 59 32 25 59
 4 11 25 11 59 31 53 11
11 59 15 11 15 15 53 53
 4 59 32 34 53 41 34 59
15 32 41 34  4 59 34 32
41 59 59  4  4 41 34 34
53 31 25 41 59 32 31 53
11 31 25 11 34 34 53 32"""

data = [[int(i) for i in line.split()] for line in data.split("\n")]


import itertools

seq = list(range(8))

min_cost = 1024
min_count = 0
for i, perm in enumerate(itertools.permutations(seq)):
    cost = sum(data[w][j] for w, j in enumerate(perm))
    if cost < min_cost:
        min_cost = cost
        min_count = 1
    elif cost == min_cost:
        min_count += 1
        print("update count at", i, "cost=", cost, "perm=", perm)

print(min_cost, min_count)