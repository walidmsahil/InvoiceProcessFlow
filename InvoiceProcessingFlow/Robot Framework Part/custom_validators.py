import re

def isRefCorrect(referencenumber):
    referencenumber = referencenumber.replace(" ", "")

#Checks if Reference number is be all digits
    if not referencenumber.isdigit():
        return False  

    checknumber = int(referencenumber[-1])  # Extract last digit as checksum
    digits = list(map(int, referencenumber[:-1]))  # Convert rest of number to list of integers

    totalAmount = 0
    multipliers = [7, 3, 1]  #Multiply fromright to left all reference number digits by 7, 3, 1, 7, 3, 1,.... sequence
    multiplier_index = 0

    # Apply weighted sum from right to left
    for digit in reversed(digits):
        totalAmount += digit * multipliers[multiplier_index]
        multiplier_index = (multiplier_index + 1) % 3 

    # Calculate the expected check digit
    calculated_check = (10 - (totalAmount % 10)) % 10

    return calculated_check == checknumber


def validate_iban_mod97(iban):
    iban = iban.replace(" ", "").upper()

    # Rearrange: move first 4 characters to the end
    rearranged = iban[4:] + iban[:4]

    # Convert letters to numbers (A=10, B=11,.... , Z=35)
    converted = "".join(str(ord(ch) - 55) if ch.isalpha() else ch for ch in rearranged)

    # Validate using Modulo 97
    remainder = int(converted) % 97
    return remainder == 1

def get_validation_message(rf_valid, iban_valid):
    if rf_valid and iban_valid:
        return "Reference number and IBAN validation passed"
    elif not rf_valid and iban_valid:
        return "Reference number validation failed"
    elif rf_valid and not iban_valid:
        return "IBAN validation failed"
    else:
        return "Reference number and IBAN validation failed"
