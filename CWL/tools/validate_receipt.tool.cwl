cwlVersion: v1.1
class: CommandLineTool

label: EBI receipt validation
doc: |
    validate upload receipt

requirements:
    InlineJavascriptRequirement: {}

stdout: validate_receipt.log
stderr: validate_receipt.error

inputs:
    receipt:
        type: File
        doc: EBI submission receipt
        inputBinding:
            prefix: --input

baseCommand: [validate_receipt.pl]

outputs:
    info:
        type: stdout
    error: 
        type: stderr

