# Convert TFsec JSON output to Reviewdog Diagnostic Format (rdjson)
# https://github.com/reviewdog/reviewdog/blob/f577bd4b56e5973796eb375b4205e89bce214bd9/proto/rdf/reviewdog.proto
{
  source: {
    name: "tfsec",
    url: "https://github.com/aquasecurity/tfsec"
  },
  diagnostics: (.results // {}) | map({
    message: .description,
    code: {
      value: .rule_id,
      url: .links[0],
    } ,
    location: {
      path: .location.filename,
      range: {
        start: {
          line: .location.start_line,
        },
      }
    },
    severity: (if .severity | startswith("HIGH") then
              "ERROR"
            elif .severity | startswith("MEDIUM") then
              "WARNING"
            elif .severity | startswith("LOW") then
              "INFO"
            else
              null
            end), 
  })
}
