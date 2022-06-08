{{/*
*
* Name Templating
*
*/}}

{{- define "name.full" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "name.short" -}}
{{- .Release.Name | trunc 32 | trimSuffix "-" -}}
{{- end -}}

{{- define "name.serviceAccount" -}}
{{- include "name.short" . | printf "%s-svcacc" -}}
{{- end -}}

{{/*
*
* White Space Control
*
*/}}

{{ define "ssh.key" }}{{ trim . | printf "%s\n" }}{{ end }}

{{/*
*
* Container Image Assembly & Such
*
*/}}

{{- define "cntr.image.uri" -}}
{{- with .Values.container.image -}}
{{- printf "%s/%s:%s" .registry .path .tag  -}}
{{- end -}}
{{- end -}}

{{- define "cntr.reg.auth" }}
{{- with .Values.container.image }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
*
* SSH Config Assembly
*
*/}}
{{- define "ssh.config" -}}
{{- with .Values.workspace.ssh.config -}}
{{ printf "%s\n### Hosts ###" .header }}
{{ range $host, $hostConfig := .hosts -}}
{{ printf "Host %s" $host }}
{{ range $confKey, $confValue := $hostConfig -}}
{{ printf "  %s %s" $confKey $confValue }}
{{ end -}}
{{ end -}}
{{- end -}}
{{- end -}}
