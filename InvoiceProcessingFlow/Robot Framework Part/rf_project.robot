*** Settings ***
Library    DatabaseLibrary
Library    RPA.Tables
Library    OperatingSystem
Library    Collections
Library    ./custom_validators.py

*** Variables ***
${DB_HOST}              localhost
${DB_PORT}              3306
${DB_NAME}              invoice
${DB_USER}              robot_user
${DB_PASSWORD}          123456

${CSV_HEADER_FILE}      C:/Users/walidmazumder/Documents/UiPath/InvoiceProcessingFlow/Robot Framework Part/InvoiceHeaderData.csv
${CSV_ROW_FILE}         C:/Users/walidmazumder/Documents/UiPath/InvoiceProcessingFlow/Robot Framework Part/InvoiceRowData.csv

*** Test Cases ***
Insert Data Into InvoiceHeader
    Connect To MySQL
    ${table_header}=    Read Table From CSV    ${CSV_HEADER_FILE}    header=True    encoding=utf-8-sig
    Log    [Header CSV Raw Data] ${table_header}
    
    ${filtered_header}=    Evaluate    [row for row in $table_header if any(row.values())]    modules=builtins
    Log    [Header CSV Filtered Data] ${filtered_header}
    
    FOR    ${row}    IN    @{filtered_header}
        Insert Row Into InvoiceHeader    ${row}
    END
    
    Execute Sql String    COMMIT;
    Close Database Connection

Insert Data Into InvoiceRow
    Connect To MySQL
    ${table_row}=    Read Table From CSV    ${CSV_ROW_FILE}    header=True    encoding=utf-8-sig
    Log    [Row CSV Raw Data] ${table_row}
    
    ${filtered_row}=    Evaluate    [row for row in $table_row if any(row.values())]    modules=builtins
    Log    [Row CSV Filtered Data] ${filtered_row}
    
    FOR    ${row}    IN    @{filtered_row}
        Insert Row Into InvoiceRow    ${row}
    END
    
    Execute Sql String    COMMIT;
    Close Database Connection

*** Keywords ***
Connect To MySQL
    Connect To Database
    ...    pymysql
    ...    db_host=${DB_HOST}
    ...    db_port=${DB_PORT}
    ...    db_name=${DB_NAME}
    ...    db_user=${DB_USER}
    ...    db_password=${DB_PASSWORD}
    
    Log    Connected to database ${DB_NAME} (Host: ${DB_HOST}, Port: ${DB_PORT})

Insert Row Into InvoiceHeader
    [Arguments]    ${row}
    Log    [Header Row Data] ${row}
    
    ${invoicenumber}=    Set Variable    ${row["InvoiceNumber"]}
    ${companyname}=      Set Variable    ${row["CompanyName"]}
    ${invoicedate}=      Set Variable    ${row["InvoiceDate"]}
    ${duedate}=          Set Variable    ${row["DueDate"]}
    ${companycode}=      Set Variable    ${row["CompanyCode"]}
    ${bankaccount}=      Set Variable    ${row["BankAccountNumber"]}
    ${amountexclvat}=    Set Variable    ${row["AmountExclVAT"]}
    ${vatamount}=        Set Variable    ${row["VATAmount"]}
    ${totalamount}=      Set Variable    ${row["TotalAmount"]}

    # Convert numeric fields to avoid errors
    ${amountexclvat}=    Evaluate    float(${amountexclvat}) if ${amountexclvat} else 0.0
    ${vatamount}=        Evaluate    float(${vatamount}) if ${vatamount} else 0.0
    ${totalamount}=      Evaluate    float(${totalamount}) if ${totalamount} else 0.0

    # Insert into InvoiceHeader table
    ${query}=    Catenate    SEPARATOR= 
    ...    INSERT INTO InvoiceHeader 
    ...        (InvoiceNumber, CompanyName, InvoiceDate, DueDate, CompanyCode, BankAccountNumber, AmountExclVAT, VATAmount, TotalAmount)
    ...    VALUES
    ...        (${invoicenumber}, '${companyname}', '${invoicedate}', '${duedate}', '${companycode}', '${bankaccount}', ${amountexclvat}, ${vatamount}, ${totalamount});
    
    Log    Final SQL Query (Header): ${query}
    Execute Sql String    ${query}
    
    # Validate RFNumber and IBAN
    ${status}    ${statusdescription}=    Validate RFNumber And IBAN    ${row["ReferenceNumber"]}    ${bankaccount}
    Insert Invoice Status    ${invoicenumber}    ${status}    ${statusdescription}

Insert Row Into InvoiceRow
    [Arguments]    ${row}
    Log    [Row Data] ${row}
    
    ${description}=    Set Variable    ${row["Description"]}
    ${quantity}=       Set Variable    ${row["Quantity"]}
    ${unit}=           Set Variable    ${row["Unit"]} 
    ${unitprice}=      Set Variable    ${row["UnitPrice"]}
    ${vatpercent}=     Set Variable    ${row["VATPercent"]}
    ${vat}=            Set Variable    ${row["VAT"]}
    ${total}=          Set Variable    ${row["Total"]}
    ${invoicenumber}=  Set Variable    ${row["InvoiceNumber"]}
    ${rownumber}=      Set Variable    ${row["RowNumber"]}
    
    # Convert numeric fields to avoid errors
    ${quantity}=    Evaluate    int(${quantity}) if ${quantity} else 0
    ${unitprice}=   Evaluate    float(${unitprice}) if ${unitprice} else 0.0
    ${vat}=         Evaluate    float(${vat}) if ${vat} else 0.0
    ${total}=       Evaluate    float(${total}) if ${total} else 0.0
    
    # Insert into InvoiceRow table
    ${query}=    Catenate    SEPARATOR= 
    ...    INSERT INTO InvoiceRow 
    ...        (InvoiceNumber, RowNumber, Description, Quantity, Unit, UnitPrice, VATPercent, VAT, Total)
    ...    VALUES
    ...        (${invoicenumber}, ${rownumber}, '${description}', ${quantity}, '${unit}', ${unitprice}, ${vatpercent}, ${vat}, ${total});
    
    Log    Final SQL Query (Row): ${query}
    Execute Sql String    ${query}

Insert Invoice Status
    [Arguments]    ${invoicenumber}    ${status}    ${statusdescription}
    
    ${query}=    Catenate    SEPARATOR= 
    ...    INSERT INTO InvoiceStatus 
    ...        (InvoiceNumber, Status, StatusDescription, StatusDate)
    ...    VALUES 
    ...        (${invoicenumber}, '${status}', '${statusdescription}', CURDATE());
    
    Log    Final SQL Query (InvoiceStatus): ${query}
    Execute Sql String    ${query}

Validate RFNumber And IBAN
    [Arguments]    ${rfnumber}    ${iban}
    
    ${rf_valid}=    Evaluate    custom_validators.isRefCorrect('${rfnumber}')    modules=custom_validators
    ${iban_valid}=  Evaluate    custom_validators.validate_iban_mod97('${iban}')    modules=custom_validators
    
    ${status}=    Set Variable If    ${rf_valid} and ${iban_valid}    Pass    Fail
    ${statusdescription}=    Evaluate    custom_validators.get_validation_message(${rf_valid}, ${iban_valid})    modules=custom_validators
    
    RETURN    ${status}    ${statusdescription}

Clear Table With Foreign Key Checks
    [Arguments]    ${table_name}
    
    Execute Sql String    SET FOREIGN_KEY_CHECKS = 0;
    Execute Sql String    TRUNCATE TABLE ${table_name};
    Execute Sql String    SET FOREIGN_KEY_CHECKS = 1;
    
    Log    Cleared all rows from ${table_name} (foreign key checks disabled)

Close Database Connection
    Disconnect From Database
