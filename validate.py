def isRefCorrect(referencenumber):
    listed = list(referencenumber)
    checknumber = listed.pop()
    totalAmount = 0
    product = 1

    while len(listed) > 0:
        if product == 1:
            product = 7
        elif product == 3:
            product = 1
        else:
            product = 3
        totalAmount += product * int(listed.pop())

    result = (10 - (totalAmount % 10)) % 10
    return result == int(checknumber)

def isEqual(headerTotal, rowTotal, maxDifference):
    if ( abs(headerTotal - rowTotal) < maxDifference):
        return True
    return False


if __name__ == '__main__':
    ref = '1431432'
    val = isRefCorrect(ref)
    print(val)


# IBAN VALIDATION 

def isIBANValid(iban):
    iban = iban.replace(" ", "")
    iban = iban.upper()

    iban = iban[4:] + iban[:4]

    converted = ""

    for char in iban:
        if char.isalpha():
            converted += str(ord(char) - 55)
        else:
            converted += char

    return int(converted) % 97 == 1
