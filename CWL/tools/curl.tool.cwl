cwlVersion: v1.0
class: CommandLineTool

label: curl
doc: authenticated upload of a file using curl

hints:
    DockerRequirement:
        dockerPull: mgrast/pipeline:4.03

requirements:
    InlineJavascriptRequirement: {}

stdout: curl.log
stderr: curl.error

inputs:
    url:
        type: string
        doc: url to connect to
        inputBinding:
            position: 1
    
    label:
        type: string
        doc: Form field name for file
        
    file:
        type: File
        doc: Upload file
    
    authBearer:
        type: String
        doc: Auth bearer name
    
    authToken:
        type: String
        doc: Auth token
    
    outName:
        type: string
        doc: Response output
        inputBinding:
            prefix: -o


baseCommand: [curl]

arguments:
    - prefix: -H
      valueFrom: |
          ${
              return "Authorization: "+inputs.authBearer+" "+inputs.authToken;
          }
    - prefix: -F
      valueFrom: |
          ${
              return inputs.label+"=@"+inputs.file.path;
          }

outputs:
    info:
        type: stdout
    error: 
        type: stderr
    output:
        type: File
        doc: Response output file
        outputBinding: 
            glob: $(inputs.outName)
