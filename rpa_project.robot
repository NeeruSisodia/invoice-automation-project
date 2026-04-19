*** Settings ***
Library   DatabaseLibrary
Library   Collections
Library   String
Library   OperatingSystem
Library   validate.py
Library   DateTime

*** Variables ***
${path}          C:/Users/hp/OneDrive/Desktop/RPAProject/
${dbname}        rpacourse
${dbuser}        robot
${dbpassword}    Devshreejodha@2015
${dbhost}        localhost
${dbport}        3306
${ListToDB}


*** Keywords ***
Make Connection
    [Arguments]  ${dbtoconnect}
    Connect To Database  db_module=pymysql  db_name=${dbname}  db_user=${dbuser}  db_password=${dbpassword}  db_host=${dbhost}  db_port=${dbport}  autocommit=${True}

Read CSV Data
    [Arguments]  
    ${outputheader}=  Get file  ${path}invoiceHeader.csv
    ${outputrows}=    Get file  ${path}dt_invoiceRow.csv
    @{headers}=       Split String  ${outputheader}  \n
    @{rows}=          Split String  ${outputrows}  \n
    Remove From List  ${headers}  0
    Remove From List  ${headers}  -1
    Remove From List  ${rows}     0
    Remove From List  ${rows}     -1
    [Return]  @{headers}  @{rows}

Add Row Data to List
    [Arguments]  @{items}  ${InvoiceNumber}
    @{AddInvoiceRowData}=  Create List
    Append To List  ${AddInvoiceRowData}  ${InvoiceNumber}
    Append To List  ${AddInvoiceRowData}  ${items[8]}
    Append To List  ${AddInvoiceRowData}  ${items[0]}
    Append To List  ${AddInvoiceRowData}  ${items[1]}
    Append To List  ${AddInvoiceRowData}  ${items[2]}
    Append To List  ${AddInvoiceRowData}  ${items[3]}
    Append To List  ${AddInvoiceRowData}  ${items[4]}
    Append To List  ${AddInvoiceRowData}  ${items[5]}
    Append To List  ${AddInvoiceRowData}  ${items[6]}
    Append To List   ${ListToDB}   ${AddInvoiceRowData}

Add Invoice Header to database
    [Arguments]  ${items}  ${InvoiceStatusID}  ${Comments}
    Make Connection  ${dbname}
    ${InvoiceNumber}=       Get From List  ${items}  0
    ${CompanyName}=         Get From List  ${items}  1
    ${CompanyCode}=         Get From List  ${items}  2
    ${ReferenceNumber}=     Get From List  ${items}  3
    ${InvoiceDate}=         Get From List  ${items}  4
    ${DueDate}=             Get From List  ${items}  5
    ${BankAccountNumber}=   Get From List  ${items}  6
    ${AmountExclVAT}=       Get From List  ${items}  7
    ${VAT}=                 Get From List  ${items}  8
    ${TotalAmount}=         Get From List  ${items}  9

    ${InsertStmt}=  Set Variable  insert into invoiceheader (invoicenumber, companyname, companycode, referencenumber, invoicedate, duedate, bankaccountnumber, amountexclvat, vat, totalamount, invoiceStatus_id, comments) values ('${InvoiceNumber}', '${CompanyName}', '${CompanyCode}', '${ReferenceNumber}', '${InvoiceDate}', '${DueDate}', '${BankAccountNumber}', ${AmountExclVAT}, ${VAT}, ${TotalAmount}, '${InvoiceStatusID}', '${Comments}');
    Log To Console   ${InsertStmt}
    ${result}=  Execute Sql String  ${InsertStmt}
    Log To Console   SQL Result: ${result}

Add Invoice Row to Database
    [Arguments]  ${items}
    Make Connection  ${dbname}
    ${InsertStmt}=  Set Variable  insert into invoicerow (invoicenumber, description, quantity, unit, unitprice, vatpercent, vat, total, rownumber) values ('${items[0]}', '${items[1]}', ${items[2]}, '${items[3]}', ${items[4]}, ${items[5]}, ${items[6]}, ${items[7]}, ${items[8]});
    Log To Console   ${InsertStmt}
    ${result}=  Execute Sql String  ${InsertStmt}
    Log To Console   SQL Result: ${result}

Validations
    [Arguments]  ${items}  ${invoiceRows}
    ${InvoiceDateRaw}=  Get From List  ${items}  4
    ${InvoiceDate}=  Convert Date  ${InvoiceDateRaw}  result_format=%Y-%m-%d  date_format=%d.%m.%y
    ${DueDateRaw}=    Get From List  ${items}  5
    ${DueDate}=  Convert Date  ${DueDateRaw}  date_format=%d.%m.%y  result_format=%Y-%m-%d

    ${statusOfInvoice}=  Set Variable  0
    ${commentOfInvoice}=  Set Variable  all ok

    ${ref}=    Get From List  ${items}  3
    ${refResult}=  Ref Correct  ${ref}
    IF  not ${refResult}
        ${statusOfInvoice}=  Set Variable  1
        ${commentOfInvoice}=  Set Variable  Reference Number Error
    END

    ${iban}=    Get From List  ${items}  6
    ${ibanResult}=  iban Correct  ${iban}
    IF  not ${ibanResult}
        ${statusOfInvoice}=  Set Variable  2
        ${commentOfInvoice}=  Set Variable  IBAN Number Error
    END

    ${invoiceTotal}=  Get From List  ${items}  9
    ${invoiceTotalsResult}=  Invoice Total Correct  ${invoiceTotal}  ${invoiceRows}  0.01
    IF  not ${invoiceTotalsResult}
        ${statusOfInvoice}=  Set Variable  3
        ${commentOfInvoice}=  Set Variable  Amount Difference
    END

    RETURN  ${statusOfInvoice}  ${commentOfInvoice}

Check IBAN
    [Arguments]  ${iban}
    ${status}=  Set Variable  ${False}
    ${iban}=  Remove String  ${iban}  ${SPACE}
    ${length}=  Get Length  ${iban}
    IF  ${length} == 18
        ${status}=  Set Variable  ${True}
    END
    RETURN  ${status}

*** Test Cases ***
Process All Invoices
    Make Connection  ${dbname}

    # ---------- Read CSVs ------#
      ${outputheader}=  Get file  ${path}invoiceHeader.csv
     ${outputrows}=  Get file  ${path}dt_invoiceRow.csv
   
  # ---------- Initialize Lists ----------
    @{headers}=    Create List
    @{rows}=       Create List 
  # Let's process each line as an individual element
  @{headers}=  Split String  ${outputheader}  \n
  @{rows}=  Split String    ${outputrows}  \n

   # Remove the first (title) line and the last (empty) line

   ${length}=  Get Length  ${headers} 
   ${length}=  Evaluate  ${length}-1
   ${index}=  Convert To Integer  0

   Remove From List  ${headers}  ${length}
   Remove From List  ${headers}  ${index}
   
    ${length}=  Get Length  ${rows}
    ${length}=  Evaluate  ${length}-1

     Remove From List  ${rows}  ${length}
     Remove From List  ${rows}  ${index}


  FOR  ${element}  IN   @{headers}  
     Log  ${element}    
  END  
  FOR  ${element}  IN   @{rows}  
     Log  ${element}    
  END 
  LOg  ${outputheader}
  Log  ${outputrows}
  Set Global Variable    @{headers}
  Set Global Variable    @{rows}

    # ---------- Initialize invoice row list ----------
    @{ListToDB}=  Create List
    ${InvoiceNumber}=  Set Variable  ''

    # ---------- Loop through each row ----------
    FOR  ${element}  IN  @{rows}
        ${element}=  Strip String  ${element}
        IF  '${element}' == ''
            Continue For Loop
        END
        @{items}=  Split String  ${element}  ;
        ${length}=  Get Length  ${items}
        IF  ${length} < 9
            Log  Skipping malformed row: ${element}
            Continue For Loop
        END

        ${rowInvoiceNumber}=  Set Variable  ${items[-1]}

        IF  '${rowInvoiceNumber}' == '${InvoiceNumber}'
            Add Row Data to List  @{items}  ${rowInvoiceNumber}
        ELSE
            ${lengthList}=  Get Length  ${ListToDB}
            IF  ${lengthList} > 0
                FOR  ${headerElement}  IN  @{headers}
                    @{headerItems}=  Split String  ${headerElement}  ;
                    ${headerInvoiceNumber}=  Get From List  ${headerItems}  0
                    IF  '${headerInvoiceNumber}' == '${InvoiceNumber}'
                        ${InvoiceStatusID}  ${Comments}=  Validations  ${headerItems}  ${ListToDB}
                        Add Invoice Header to database  @{headerItems}  ${InvoiceStatusID}  ${Comments}
                        FOR  ${rowElement}  IN  @{ListToDB}
                            Add Invoice Row to Database  @{rowElement}
                        END
                    END
                END
            END
            @{ListToDB}=  Create List
            ${InvoiceNumber}=  Set Variable  ${rowInvoiceNumber}
            Add Row Data to List  @{items}  ${rowInvoiceNumber}
        END
    END

    # ---------- Process last invoice ----------
    ${lengthList}=  Get Length  ${ListToDB}
    IF  ${lengthList} > 0
        FOR  ${headerElement}  IN  @{headers}
            @{headerItems}=  Split String  ${headerElement}  ;
            ${headerInvoiceNumber}=  Get From List  ${headerItems}  0
            IF  '${headerInvoiceNumber}' == '${InvoiceNumber}'
                ${InvoiceStatusID}  ${Comments}=  Validations  ${headerItems}  ${ListToDB}
                Add Invoice Header to database  @{headerItems}  ${InvoiceStatusID}  ${Comments}
                FOR  ${rowElement}  IN  @{ListToDB}
                    Add Invoice Row to Database  @{rowElement}
                END
            END
        END
    END
