*** Settings ***
Library   DatabaseLibrary
Library   Collections
Library   String
Library   OperatingSystem
Library   validate.py
Library    DateTime

*** Variables ***
${path}    C:/Users/hp/OneDrive/Desktop/RPAProject/
@{ListToDB}
${InvoiceNumber}  empty
${DueDate}
${InvoiceStatusID} 
${Comments} 
${element}
${length}
${index}
# Database user auxilary variable
${dbname}  rpacourse
${dbuser}    robot
${dbpassword}    Devshreejodha@2015
${dbhost}    localhost
${dbport}    3306

*** Keywords ***
Make Connection
  [Arguments]  ${dbtoconnect}
  Connect To Database  db_module=pymysql  db_name=${dbname}  db_user=${dbuser}   db_password=${dbpassword}  db_host=${dbhost}  db_port=${dbport}  autocommit=${True}

*** Keywords ***  
Add Row Data to List
   # one keyword to handling data row to be written to database
   [Arguments]   @{items}  ${InvoiceNumber}

   @{AddInvoiceRowData}=   Create List
   Append To List    ${AddInvoiceRowData}  ${InvoiceNumber}
   Append To List    ${AddInvoiceRowData}  ${items}[8]
   Append To List    ${AddInvoiceRowData}  ${items}[0]
   Append To List    ${AddInvoiceRowData}  ${items}[1]
   Append To List    ${AddInvoiceRowData}  ${items}[2]
   Append To List    ${AddInvoiceRowData}  ${items}[3]
   Append To List    ${AddInvoiceRowData}  ${items}[4]
   Append To List    ${AddInvoiceRowData}  ${items}[5]
   Append To List    ${AddInvoiceRowData}  ${items}[6]


   Append To List   ${ListToDB}   ${AddInvoiceRowData}

*** Keywords ***
Add Invoice Header to database
   # Add data invoice header data to database
   [Arguments]   ${items}  ${InvoiceStatusID}  ${Comments}
   Make Connection  ${dbname}
   Log To Console    INSERT HEADER CALLED: ${items}


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

   #Log ${InsertStmt}
   ${InsertStmt}=  Set Variable  insert into invoiceheader (invoicenumber, companyname, companycode, referencenumber, invoicedate, duedate, bankaccountnumber, amountexclvat, vat, totalamount, invoiceStatus_id, comments) values ('${InvoiceNumber}', '${CompanyName}', '${CompanyCode}', '${ReferenceNumber}', '${InvoiceDate}', '${DueDate}', '${BankAccountNumber}', ${AmountExclVAT}, ${VAT}, ${TotalAmount}, '${InvoiceStatusID}', '${Comments}');
    Log To Console   ${InsertStmt}
    ${result}=  Execute Sql String  ${InsertStmt}
    Log To Console   SQL Result: ${result}
    Execute Sql String  ${InsertStmt}
    
   
# validations

Validations   
   [Arguments]   ${items}   ${invoiceRows}
   
   #1 Covert date to right format
   ${InvoiceDateRaw}=  Get From List    ${items}    4
   ${InvoiceDate}=  Convert Date  ${InvoiceDateRaw}  result_format=%Y-%m-%d  date_format=%d.%m.%y
   ${DueDateRaw}=    Get From List    ${items}    5
   ${DueDate}= Convert Date  ${DueDateRaw}  date_format=%d.%m.%y  result_format=%Y-%m-%d

   #2 amounts
   #3 db create to decimal(10,2)
   ${statusOfInvoice}=  Set Variable  0
   ${commentOfInvoice}=  Set Variable  all ok
   # to check reference
   ${ref}=    Get From List    ${items}    3
   ${refResult}=  Ref Correct  ${ref}

   IF  not ${refResult}
      ${statusOfInvoice}=  Set Variable  1
      ${commentOfInvoice}=  Set Variable  Reference Number Error
   END   
    # to check IBAN number
   ${iban}=    Get From List    ${items}    6
   ${ibanResult}=  iban Correct  ${iban}

   IF  not ${ibanResult}
      ${statusOfInvoice}=  Set Variable  2
      ${commentOfInvoice}=  Set Variable  IBAN Number Error
   END
   # to check invoice total
   ${invoiceTotal}=    Get From List    ${items}    9
   ${invoiceTotalsResult}=   Invoice Total Correct   ${invoiceTotal}  ${invoiceRows}  0.01
   
   IF  not ${invoiceTotalsResult}
      ${statusOfInvoice}=  Set Variable  3
      ${commentOfInvoice}=  Set Variable    Amount Difference
   END 
   
   RETURN  ${statusOfInvoice}  ${commentOfInvoice}
   

*** Keywords ***
Check Amounts From Invoice
     [Arguments]  ${totalSumFromHeader}  ${invoiceRows}   
     ${status}=  Set Variable  ${False} 
     ${totalRowAmount}=  Evaluate  0

     FOR  ${element}  IN  @{invoiceRows}
          #log to console  ${element}[8]
          ${totalRowAmount}= Evaluate  ${totalRowAmount}+${element}[8]
     END 
     ${totalSumFromHeader}=  Convert To Number    ${totalSumFromHeader} 
     ${totalRowAmount}=  Convert To Number    ${totalRowAmount}
     ${diff}=  Convert To Number    0.01  

     ${status}= Is Equal  ${totalSumFromHeader}  ${totalRowAmount}  ${diff}

     RETURN  ${status}

*** Keywords ***
Check IBAN
     [Arguments]      ${iban}
     #Log to console ${iban}
     ${status}=  Set Variable  ${False}
     ${iban}=  Remove String    ${iban}  ${SPACE}

     ${length}= Get Length  ${iban}

     #Log Console to ${length}

     IF  ${length} == 18
         ${status}=  Set Variable  ${True}
     END
     RETURN  ${status}  

*** Keywords ***
Add Invoice Row to Database
    [Arguments]  ${items}  
    Log To Console    INSERT ROW CALLED: ${items}
    Make Connection  ${dbname}
    ${InsertStmt}=  Set Variable  insert into invoicerow (invoicenumber, description, quantity, unit, unitprice, vatpercent, vat, total, rownumber) values ('${items}[0]', '${items}[1]', ${items}[2], '${items}[3]', ${items}[4], ${items}[5], ${items}[6], ${items}[7], ${items}[8]);
    Log To Console   ${InsertStmt}
    ${result}=  Execute Sql String  ${InsertStmt}
    Log To Console   SQL Result: ${result}
    Execute Sql String  ${InsertStmt}


    



*** Test Cases ***
Read CSV file to list
  Make Connection  ${dbname}
  ${outputheader}=  Get file  ${path}invoiceHeader.csv
  ${outputrows}=  Get file  ${path}dt_invoiceRow.csv
   
  # create list
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

   
#*** Test Cases ***
Loop All Invoices 
    # Initialize the list to store invoice rows
    @{ListToDB}=  Create List
    Set Global Variable  @{ListToDB}

    # Track previous invoice number
    ${InvoiceNumber}=  Set Variable  ''

    # Loop through each row from CSV
    FOR  ${element}  IN  @{rows}
        ${element}=  Strip String  ${element}

        # Skip completely empty rows
        IF  '${element}' == ''
            Log  Skipping empty row
            Continue For Loop
        END

        # Split row into items and preserve empty strings
        @{items}=  Split String  ${element}  ;

        ${length}=  Get Length  ${items}
        IF  ${length} < 9
            Log  Skipping malformed row: ${element}
            Continue For Loop
        END

        # Invoice number for this row (last column in row CSV)
        ${rowInvoiceNumber}=  Set Variable  ${items[-1]}

        # First invoice or same invoice as previous
        IF  '${rowInvoiceNumber}' == '${InvoiceNumber}'
            Add Row Data to List  @{items}  ${rowInvoiceNumber}
        ELSE
            # New invoice encountered: process previous invoice if exists
            ${lengthList}=  Get Length  ${ListToDB}
            IF  ${lengthList} > 0
                Log  Processing previous invoice: ${InvoiceNumber}

                # Find header for previous invoice
                FOR  ${headerElement}  IN  @{headers}
                    @{headerItems}=  Split String  ${headerElement}  ;
                    ${headerInvoiceNumber}=  Get From List  ${headerItems}  0
                    Log To Console   Comparing: ${headerInvoiceNumber} WITH ${InvoiceNumber}
                    IF  '${headerInvoiceNumber}' == '${InvoiceNumber}'
                        Log  Invoice header found: ${InvoiceNumber}

                        # Run validations
                        ${InvoiceStatusID}  ${Comments}=  Validations  ${headerItems}  ${ListToDB}

                        # Add header to database using parameterized query
                        Add Invoice Header to database  @{headerItems}  ${InvoiceStatusID}  ${Comments}

                        # Add all invoice rows to database
                        FOR  ${rowElement}  IN  @{ListToDB}
                            Add Invoice Row to Database  @{rowElement}
                        END
                    END
                END
            END

            # Reset list for new invoice
            @{ListToDB}=  Create List
            Set Global Variable  @{ListToDB}

            # Set current invoice number
            ${InvoiceNumber}=  Set Variable  ${rowInvoiceNumber}

            # Add current row
            Add Row Data to List  @{items}  ${rowInvoiceNumber}
        END
    END

    # Handle the last invoice after loop
    ${lengthList}=  Get Length  ${ListToDB}
    IF  ${lengthList} > 0
        Log  Processing last invoice: ${InvoiceNumber}
        FOR  ${headerElement}  IN  @{headers}
            @{headerItems}=  Split String  ${headerElement}  ;
            ${headerInvoiceNumber}=  Get From List  ${headerItems}  0
            Log To Console   Comparing: ${headerInvoiceNumber} WITH ${InvoiceNumber}
            IF  '${headerInvoiceNumber}' == '${InvoiceNumber}'
                Log  Invoice header found for last invoice: ${InvoiceNumber}
                ${InvoiceStatusID}  ${Comments}=  Validations  ${headerItems}  ${ListToDB}
                Add Invoice Header to database  @{headerItems}  ${InvoiceStatusID}  ${Comments}
                FOR  ${rowElement}  IN  @{ListToDB}
                    Add Invoice Row to Database  @{rowElement}
                END
            END
        END
    END