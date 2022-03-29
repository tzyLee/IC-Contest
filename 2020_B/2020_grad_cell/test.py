def main():
    with open("./Btestdata.txt", "r") as f:
        string = ""
        pattern = ""
        for line in f:
            line = line.rstrip()
            if line.startswith("pat"):
                _, _, match, idx, pattern = line.split(":")
                is_match = match == "1"
                match_idx = int(idx)

                print('Matching s="{}", p="{}"'.format(string, pattern))
                match_idx_ans, is_match_ans = try_match(string, pattern)
                print(
                    "{}={}, {}={}".format(
                        is_match, is_match_ans, match_idx, match_idx_ans
                    )
                )
                if is_match != is_match_ans or is_match and match_idx != match_idx_ans:
                    break
            else:
                _, _, string = line.split(":")
        else:
            print("All pass")


def try_match(s, p):
    sn = len(s)
    pn = len(p)
    sj = si = 0
    pi = 0

    MATCH = 1
    MATCH_WILD = 2
    OUTPUT = 3

    def accept(sc, pc):
        if pc == ".":
            return True
        return sc == pc

    if p[0] == "^":
        pi = 1
    else:
        pi = 0

    wild_begin = 0
    match = False
    state = MATCH
    while True:
        # if state == MATCH:
        #     print(
        #         "M '{}[{}]{}', '{}[{}]{}'".format(
        #             s[:si], s[si], s[si + 1 :], p[:pi], p[pi], p[pi + 1 :]
        #         )
        #     )
        #     if p[pi] == "*":
        #         state = MATCH_WILD
        #         wild_begin = pi + 1
        #         pi += 1
        #     else:
        #         if accept(s[si], p[pi]) or (p[pi] == "^" and s[si] == " "):
        #             si += 1
        #             pi += 1
        #         else:
        #             si = sj + 1
        #             sj = sj + 1
        #             pi = 0
        # elif state == MATCH_WILD:
        #     print(
        #         "W '{}[{}]{}', '{}[{}]{}'".format(
        #             s[:si], s[si], s[si + 1 :], p[:pi], p[pi], p[pi + 1 :]
        #         )
        #     )
        #     if accept(s[si], p[pi]) or (
        #         p[pi] == "^" and s[si] == " "
        #     ):  # Redundant ^ check
        #         si += 1
        #         pi += 1
        #     else:
        #         si += 1
        #         pi = wild_begin
        if state == MATCH or state == MATCH_WILD:
            print(
                "{} '{}[{}]{}', '{}[{}]{}'".format(
                    "M" if state == MATCH else "W",
                    s[:si],
                    s[si],
                    s[si + 1 :],
                    p[:pi],
                    p[pi],
                    p[pi + 1 :],
                )
            )
            if p[pi] == "*":
                state = MATCH_WILD
                wild_begin = pi + 1
                pi += 1
            else:
                if accept(s[si], p[pi]) or (p[pi] == "^" and s[si] == " "):
                    si += 1
                    pi += 1
                else:
                    if state == MATCH_WILD:
                        si += 1
                        sj = sj
                    else:
                        si = sj + 1
                        sj = sj + 1
                    pi = wild_begin
        elif state == OUTPUT:
            print("break")
            break
        if pi == pn or p[pi] == "$" and (si == sn or s[si] == " "):
            state = OUTPUT
            match = True
        elif si == sn:
            state = OUTPUT
            match = False

    if p[0] == "^" and sj != 0:
        sj += 1
    return sj, match


if __name__ == "__main__":
    main()
    print(try_match("siaaace siaaacde cd", "si*cd$"))
