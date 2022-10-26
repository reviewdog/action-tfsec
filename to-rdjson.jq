# Convert KICS JSON output to Reviewdog Diagnostic Format (rdjson)
# https://github.com/reviewdog/reviewdog/blob/f577bd4b56e5973796eb375b4205e89bce214bd9/proto/rdf/reviewdog.proto
{
  source: {
    name: "kics",
    url: "https://github.com/Checkmarx/kics"
  },
  diagnostics: (.queries // {}) 
| map(.query_url as $rule_url
| .files[] = {
  message: .description,
  code: {
      value: .query_name,
      url: .query_url,
  },
  location: {
      path: .files[].file_name,
      range: {
        start: {
          line: .files[].line,
        },
      }
    },
  severity: (if .severity | startswith("HIGH") then
              "ERROR"
            elif .severity | startswith("MEDIUM") then
              "WARNING"
            elif .severity | startswith("LOW") then
              "INFO"
            elif .severity | startswith("INFO") then
              "INFO"  
            else
              "null"
            end), 
})  
| map(.files) | flatten | unique_by(.code.value)
}
