# Определяем новую функцию
{{- define "comment.fullname" -}}
# printf функция которая создает строку из заданного значения
# Мы созадем строку <release_name>-<chart_name> используя значения .Release.Name и .Chart.Name.
{{- printf "%s-%s" .Release.Name .Chart.Name }}
{{- end -}}
