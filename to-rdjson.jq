# Convert trivy JSON output to Reviewdog Diagnostic Format (rdjson)
# https://github.com/reviewdog/reviewdog/blob/f577bd4b56e5973796eb375b4205e89bce214bd9/proto/rdf/reviewdog.proto
{
  source: {
    name: "trivy",
    url: "https://github.com/aquasecurity/trivy"
  },
  diagnostics: [(.Results[]
    | .Target as $target
    | .Misconfigurations
    | select(. != null)
    | .[]
    | .Title as $title | .ID as $id | .PrimaryURL as $primaryURL | .Severity as $severity
    | .CauseMetadata | {
    message: $title,
    code: {
      value: $id,
      url: $primaryURL,
    } ,
    location: {
      path: $target,
      range: {
        start: {
          line: .StartLine,
        },
        # Not in for tfsec
        #end: {
        #  line: .EndLine,
        #},
      }
    },
    severity: (if $severity | startswith("CRITICAL") then
              "ERROR"
            elif $severity | startswith("HIGH") then
              "ERROR"              
            elif $severity | startswith("MEDIUM") then
              "WARNING"
            elif $severity | startswith("LOW") then
              "INFO"
            else
              null
            end), 
  })]
}
