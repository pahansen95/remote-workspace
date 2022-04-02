{{/*
*
* Name Templating
*
*/}}

{{- define "name.full" -}}
{{- default .Chart.Name .Values.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "name.short" -}}
{{- include "name.full" . | trunc 8 | trimSuffix "-" -}}
{{- end -}}

{{- define "name.serviceAccount" -}}
{{- include "name.short" . | printf "%s-sa" -}}
{{- end -}}

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
