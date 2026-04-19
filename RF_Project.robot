*** Settings ***
Library    String
Library    Collections
Library    OperatingSystem
Library    DatabaseLibrary
Library    DateTime
Library    validate.py

*** Variables ***
${PATH}           C:/Users/hp/OneDrive/Desktop/RPAProject/
@{ListToDB}
${InvoiceNumber}  ${EMPTY}

${dbname}         rpacourse
${dbuser}         robot
${dbpass}         Devshreejodha@2015
${dbhost}         localhost
${dbport}         3306

*** Keywords ***

Make Connection
    [Arguments]    ${dbtoconnect}
    Connect To Database
    ...    db_module=pymysql
    ...    db_name=${dbtoconnect}
    ...    db_user=${dbuser}
    ...    db_password=${dbpass}
    ...    db_host=${dbhost}
    ...    db_port=${dbport}

Ensure Invoice Status Exists
    ${count}=    Query    SELECT COUNT(*) FROM invoicestatus;
    ${count}=    Convert To Integer    ${count}[0][0]

    IF    ${count} == 0
        Execute Sql String    INSERT INTO invoicestatus (id, name) VALUES (0,'Approved');
        Execute Sql String    INSERT INTO invoicestatus (id, name) VALUES (1,'Reference Error');
        Execute Sql String    INSERT INTO invoicestatus (id, name) VALUES (2,'IBAN Error');
        Execute Sql String    INSERT INTO invoicestatus (id, name) VALUES (3,'Amount Mismatch');
    END

Add Row Data to List
    [Arguments]    ${items}
    @{AddInvoiceRowData}=    Create List
    Append To List    ${AddInvoiceRowData}    ${InvoiceNumber}
    Append To List    ${AddInvoiceRowData}    ${items[8]}
    Append To List    ${AddInvoiceRowData}    ${items[0]}
    Append To List    ${AddInvoiceRowData}    ${items[1]}
    Append To List    ${AddInvoiceRowData}    ${items[2]}
    Append To List    ${AddInvoiceRowData}    ${items[3]}
    Append To List    ${AddInvoiceRowData}    ${items[4]}
    Append To List    ${AddInvoiceRowData}    ${items[5]}
    Append To List    ${AddInvoiceRowData}    ${items[6]}

    Append To List    ${ListToDB}    ${AddInvoiceRowData}

Add Invoice Header To DB
    [Arguments]    ${items}    ${rows}
    ${invoiceDate}=    Convert Date    ${items[3]}    date_format=%d.%m.%Y    result_format=%Y-%m-%d
    ${dueDate}=        Convert Date    ${items[4]}    date_format=%d.%m.%Y    result_format=%Y-%m-%d

    ${statusOfInvoice}=    Set Variable    0
    ${commentOfInvoice}=   Set Variable    All ok

    ${refResult}=    Is Ref Correct    ${items[2]}
    IF    not ${refResult}
        ${statusOfInvoice}=    Set Variable    1
        ${commentOfInvoice}=   Set Variable    Reference number error
    END

    ${ibanResult}=    Is IBAN Valid    ${items[6]}
    IF    not ${ibanResult}
        ${statusOfInvoice}=    Set Variable    2
        ${commentOfInvoice}=   Set Variable    IBAN number error
    END

    ${sumResult}=    Check Amounts From Invoice    ${items[9]}    ${rows}
    IF    not ${sumResult}
        ${statusOfInvoice}=    Set Variable    3
        ${commentOfInvoice}=   Set Variable    Amount difference
    END

    ${insertStmt}=    Catenate    SEPARATOR=
    ...    insert into invoiceheader
    ...    (invoicenumber, companyname, companycode, referencenumber,
    ...     invoicedate, duedate, bankaccountnumber,
    ...     amountexclvat, vat, totalamount, invoicestatus_id, comments)
    ...    values
    ...    ('${items[0]}', '${items[1]}', '${items[5]}', '${items[2]}',
    ...     '${invoiceDate}', '${dueDate}', '${items[6]}',
    ...     '${items[7]}', '${items[8]}', '${items[9]}',
    ...     '${statusOfInvoice}', '${commentOfInvoice}');

    Execute Sql String    ${insertStmt}

Add Invoice Row To DB
    [Arguments]    ${items}
    ${insertStmt}=    Catenate    SEPARATOR=
    ...    insert into invoicerow
    ...    (invoicenumber, rownumber, description, quantity,
    ...     unit, unitprice, vatpercent, vat, total, InvoiceHeader_invoicenumber)
    ...    values
    ...    ('${items[0]}', '${items[1]}', '${items[2]}',
    ...     '${items[3]}', '${items[4]}', '${items[5]}',
    ...     '${items[6]}', '${items[7]}', '${items[8]}', '${items[0]}');

    Execute Sql String    ${insertStmt}

Check Amounts From Invoice
    [Arguments]    ${totalSumFromHeader}    ${invoiceRows}
    ${status}=    Set Variable    ${True}
    ${totalRowsAmount}=    Evaluate    0

    FOR    ${element}    IN    @{invoiceRows}
        ${quantity}=    Convert To Number    ${element[3]}
        ${unitprice}=   Convert To Number    ${element[5]}
        ${vat}=         Convert To Number    ${element[7]}
        ${rowTotal}=    Convert To Number    ${element[8]}

        ${calculated}=    Evaluate    ${quantity} * ${unitprice} + ${vat}
        ${diffRow}=       Evaluate    abs(${calculated} - ${rowTotal})

        IF    ${diffRow} > 0.01
            ${status}=    Set Variable    ${False}
        END

        ${totalRowsAmount}=    Evaluate    ${totalRowsAmount} + ${rowTotal}
    END

    ${totalSumFromHeader}=    Convert To Number    ${totalSumFromHeader}
    ${diffHeader}=    Evaluate    abs(${totalSumFromHeader} - ${totalRowsAmount})

    IF    ${diffHeader} > 0.01
        ${status}=    Set Variable    ${False}
    END

    RETURN    ${status}

*** Test Cases ***

Read CSV file to list
    ${outputHeader}=    Get File    ${PATH}invoiceHeader.csv
    ${outputRows}=      Get File    ${PATH}dt_invoiceRow.csv

    @{headers}=    Split String    ${outputHeader}    \n
    @{rows}=       Split String    ${outputRows}      \n

    Remove From List    ${headers}    0
    Remove From List    ${rows}       0

    # Strip \r\n whitespace and remove empty lines
    ${headers}=    Evaluate    [h.strip() for h in $headers if h.strip()]
    ${rows}=       Evaluate    [r.strip() for r in $rows if r.strip()]

    Set Global Variable    ${headers}
    Set Global Variable    ${rows}

Initialize Database
    Make Connection    ${dbname}
    Ensure Invoice Status Exists
    Disconnect From Database

Loop all invoicerows
    Make Connection    ${dbname}

    FOR    ${element}    IN    @{rows}

        Continue For Loop If    '${element}' == ''

        ${element}=    Strip String    ${element}
        @{items}=      Split String    ${element}    ,

        # Strip whitespace and \r from each item
        @{cleanItems}=    Create List
        FOR    ${item}    IN    @{items}
            ${item}=    Strip String    ${item}
            Append To List    ${cleanItems}    ${item}
        END

        ${rowInvoiceNumber}=    Set Variable    ${cleanItems[7]}

        IF    '${rowInvoiceNumber}' == '${InvoiceNumber}'
            Add Row Data to List    ${cleanItems}
        ELSE
            ${length}=    Get Length    ${ListToDB}

            IF    ${length} > 0
                FOR    ${headerElement}    IN    @{headers}
                    ${headerElement}=       Strip String    ${headerElement}
                    @{headerItems}=         Split String    ${headerElement}    ,
                    @{cleanHeaderItems}=    Create List
                    FOR    ${hitem}    IN    @{headerItems}
                        ${hitem}=    Strip String    ${hitem}
                        Append To List    ${cleanHeaderItems}    ${hitem}
                    END
                    IF    '${cleanHeaderItems[0]}' == '${InvoiceNumber}'
                        Add Invoice Header To DB    ${cleanHeaderItems}    ${ListToDB}
                        FOR    ${rowElement}    IN    @{ListToDB}
                            Add Invoice Row To DB    ${rowElement}
                        END
                    END
                END
            END

            @{ListToDB}=    Create List
            Set Global Variable    ${ListToDB}

            ${InvoiceNumber}=    Set Variable    ${rowInvoiceNumber}
            Set Global Variable    ${InvoiceNumber}

            Add Row Data to List    ${cleanItems}
        END
    END

    # Process the last invoice group after loop ends
    ${length}=    Get Length    ${ListToDB}
    IF    ${length} > 0
        FOR    ${headerElement}    IN    @{headers}
            ${headerElement}=       Strip String    ${headerElement}
            @{headerItems}=         Split String    ${headerElement}    ,
            @{cleanHeaderItems}=    Create List
            FOR    ${hitem}    IN    @{headerItems}
                ${hitem}=    Strip String    ${hitem}
                Append To List    ${cleanHeaderItems}    ${hitem}
            END
            IF    '${cleanHeaderItems[0]}' == '${InvoiceNumber}'
                Add Invoice Header To DB    ${cleanHeaderItems}    ${ListToDB}
                FOR    ${rowElement}    IN    @{ListToDB}
                    Add Invoice Row To DB    ${rowElement}
                END
            END
        END
    END

    Disconnect From Database