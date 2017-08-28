cwlVersion: v1.0
class: CommandLineTool

label: submit MG-RAST Project
doc: |
    create the ENA XML files for a MG-RAST Project and submit them to EBI
    >submit_project.pl

hints:
    DockerRequirement:
        dockerPull: mgrast/ebi:0.2
    
requirements:
    InlineJavascriptRequirement: {}

stdout: submit_project.log
stderr: submit_project.error

inputs:
    project:
        type: string
        doc: MG-RAST Project ID
        inputBinding:
            prefix: --project_id
    
    uploads:
        type: File
        doc: Metagenome upload list file
        format:
            - Formats:tsv
        inputBinding:
            prefix: --upload_list
    
    outName:
        type: string?
        doc: Submission receipt
        default: receipt.xml
        inputBinding:
            prefix: --output
    
    mgrastUrl:
        type: string?
        doc: MG-RAST API URL
        default: http://api.metagenomics.anl.gov/
        inputBinding:
            prefix: --mgrast_url
    
    submitUrl:
        type: string?
        doc: EBI Submission URL
        default: https://www.ebi.ac.uk/ena/submit/drop-box/submit/
        inputBinding:
            prefix: --submit_url
    
    submitUser:
        type: string?
        doc: Optional Submission URL login
        inputBinding:
            prefix: --user
    
    submitPassword:
        type: string?
        doc: Optional Submission URL password
        inputBinding:
            prefix: --password
    
    submitOption:
        type: string?
        doc: Optional Submission type
        default: ADD
        inputBinding:
            prefix: --submit_option


baseCommand: submit_project.pl

arguments:
    - prefix: --temp_dir
      valueFrom: $(runtime.tmpdir)
    - prefix: --verbose

outputs:
    info:
        type: stdout
    error: 
        type: stderr
    output:
        type: File
        doc: Submission receipt file
        outputBinding:
            glob: $(inputs.outName)

$namespaces:
    Formats: FileFormats.cv.yaml

