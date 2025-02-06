#!/bin/sh

# Globals

# Client request
request

# Page request path properties
query

# Form submisisons
form_data

# Render templates
templates


# Helper functions


# Ternary helper
t() {
	if [ "$1" ]; then
		echo "$2"
	else
		echo "$3"
	fi
}

# Test if the current shell is Korn or Bash
isKsh() {
	if [[ -n "$KSH_VERSION" ]]; then
		return 0
	fi
	
	# Probably Bash
	return 1
}

# Local associative array helper
array() {
	local arr="$1"
	
	isKsh
	if [[ $? -eq 0 ]]; then
		eval "typeset -A $arr"
	else
		eval "declare -A $arr"
	fi
}



# Templates


array templates
temp=$(cat <<'HTML'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="/style.css">
<title>{page_title}</title></head>
<body>
{body}
</body>
</html>
HTML
)
templates[tpl_full_page]="$temp"


temp=$(cat <<'HTML'
<article>
<header>
<div class="content">
	<h2><a href="{permalink}">{title}</a></h2>
	<time datetime="{date_utc}">{date_stamp}</time>
</div>
</header>
{body}
</article>
HTML
)
templates[tpl_post]="$temp"


temp=$(cat <<'HTML'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="/style.css">
<title>{page_title}</title></head>
<body>
<div class="content">
{body}
</div>
</body>
</html>
HTML
)
templates[tpl_post_page]="$temp"


temp=$(cat <<'HTML'
<li><a href="{tag_link}">{tag}</a></li>
HTML
)
templates[tpl_tag]="$temp"

temp=$(cat <<'HTML'
<nav><ul class="tags">
{tags}
</ul></nav>
HTML
)
templates[tpl_taglist]="$temp"


temp=$(cat <<'HTML'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="/style.css">
<title>No more posts</title></head>
<body>
<h1>No more posts</h1>
<p>You have reached the end of your search results</p>
<p><a href="/">Back</a></p>
</body>
</html>
HTML
)
templates[tpl_noresults]="$temp"


temp=$(cat <<'HTML'
<html>
<head><title>Method Not Allowed</title></head>
<body>
<h1>Not Allowed</h1>
<p>The request method you have used is not supported</p>
</body>
</html>
HTML
)
templates[tpl_nomethod]="$temp"

temp=$(cat <<'HTML'
<html>
<head><title>Forbidden</title></head>
<body>
<h1>Access Denied</h1>
<p>The resource you are trying to reach is restricted</p>
<p><a href="/">Back</a></p>
</body>
</html>
HTML
)
templates[tpl_forbidden]="$temp"

temp=$(cat <<'HTML'
<html>
<head><title>Page Not Found</title></head>
<body>
<h1>Page Not Found</h1>
<p>The resource you are looking for could not be located</p>
<p><a href="/">Back</a></p>
</body>
</html>
HTML
)
templates[tpl_notfound]="$temp"



# Client IO



# Load HTTP request params and headers sent by the visitor
loadRequest() {
	array request
	
	# Loop through environment variables and extract headers
	for header in $(env | grep -i "HTTP_"); do
		local key=$(echo $header | cut -d= -f1 | sed 's/HTTP_//g' | tr 'A-Z' 'a-z' | tr '_' '-')
		local value=$(echo $header | cut -d= -f2)
		
		# Store in the associative array
		request["$key"]="$value"
	done
	
	# Query params
	request["verb"]=$(echo $REQUEST_METHOD | tr '[:upper:]' '[:lower:]')
	request["uri"]=$REQUEST_URI
}

# Static headers
preamble() {
	local code=$1
	local ctype=$2
	
	# Response code
	if [[ "$code" = 200 ]]; then
		echo "Status: 200 OK"
	elif [[ "$code" = 204 ]]; then
		echo "Status: 204 No Content"
	elif [[ "$code" = 403 ]]; then
		echo "Status: 403 Forbidden"
	elif [[ "$code" = 405 ]]; then
		echo "Status: 405 Method Not Allowed"
	elif [[ "$code" = 400 ]]; then
		echo "Status: 400 Bad Request"
	else
		echo "Status: 404 Not Found"
	fi
	
	# Added content type?
	if [[ "$ctype" = 'text' ]]; then
		echo "Content-type: text/plain"
	elif [[ "$ctype" = 'none' ]]; then
		: # Do nothing
	else
		echo "Content-type: text/html"
	fi
}

# Options response
allowHeaders() {
	if [ -z $1 ]; then
		# Regular allow response
		preamble 204 "none"
	else
		# Not allowed response
		preamble 405 "none"
	fi
	
	dt=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
	echo "Allow: OPTIONS, GET, HEAD"
	echo "Cache-Control: max-age=604800"
	echo "Date: ${dt}"
}

# Format HTML templates with placeholder replacement data
render() {
	local tpl="$1"
	local out="$tpl"
	local data
	
	array data
	
	eval "data=($2)"
	for key in "${!data[@]}"; do
		out=$(echo "$out" | sed "s|{$key}|${data[$key]}|g")
	done
	echo "$out"
}

# Unkown or page/resource not found page
sendNotFound() {
	preamble 404
	echo "${templates[tpl_notfound]}"
	exit
}

# Method not allowed
sendNotAllowed() {
	allowHeaders 1
	echo "Content-type: text/html"
	echo "${templates[tpl_nomethod]}"
	exit
}

# Forbidden page
sendDenied() {
	preamble 403
	echo "${templates[tpl_forbidden]}"
	exit
}

# Response filter
filter() {
	# Invalid requests
	if [ -z "${request["host"]}" ] || [ -z "${request["user-agent"]}" ]; then
		preamble 400 "none"
		exit
	fi
	
	# Limit request methods
	if [[ "${request["verb"]}" != "head" && 
		"${request["verb"]}" != "get" && 
		"${request["verb"]}" != "options" ]]; then
		sendNotAllowed
	fi
	
	# Send options response
	if [[ "${request["verb"]}" == "options" ]]; then
		allowHeaders
		exit
	fi
}

# Load archive array with passed URI parameters
requestUri() {
	local uri=$1
	
	array query
	
	# Search sent
	query[search]=$(echo "$uri" | sed -E 's|^/\?search=([^/]+)(/.*)?$|\1|')
	
	# Last, "page" prefixed, string segment
	query[page]=$(echo "$uri" | sed -E 's|.*/page([1-9][0-9]{0,2})$|\1|')
	
	# Static entry E.G. "about"
	query[article]=$(echo "$uri" | sed -E 's|^/([a-zA-Z0-9_-\/]{1,255})$|\1|')
	
	# If not searching, try archive
	if [ -z "${query[search]}" ]; then
		query[year]=$(echo "$uri" | sed -E 's|^/([0-9]{4})(/.*)?$|\1|')
		query[month]=$(echo "$uri" | sed -E 's|^/[0-9]{4}/([0-9]{2})(/.*)?$|\1|')
		query[day]=$(echo "$uri" | sed -E 's|^/[0-9]{4}/[0-9]{2}/([0-9]{2})(/.*)?$|\1|')
	fi
	
	# If not paged path or search, try "slug" string segment
	if [ -z "${query[page]}" ] && [ -z "${query[search]}" ]; then
		query[slug]=$(echo "$uri" | sed -E 's|^/[0-9]{4}/[0-9]{2}/[0-9]{2}/([a-zA-Z0-9_-]{1,255})$|\1|')
	fi
}



# Form processing



# Process form field into associative array
formField() {
	local line="$1"
	local field_name=""
	local field_value=""
	
	isKsh
	if [[ $? -eq 0 ]]; then
		# Korn shell, use grep and sed
		field_name=$(echo "$line" | grep -o 'name="[^"]*"' | sed 's/name="\([^"]*\)"/\1/')
	else
		# Or in Bash
		if [[ "$line" =~ Content-Disposition.*name=\"([^\"]+)\" ]]; then
			field_name="${BASH_REMATCH[1]}"
		fi
	fi
	
	# Invalid field name?
	if [[ -z "$field_name" ]]; then
		return 1
	fi
	
	if [[ "$line" =~ "filename=" ]]; then
		local filename=$(echo "$line" | sed 's/.*filename="\(.*\)"/\1/')
		local tmpfile=$(mktemp)
		
		# TODO: Refine file uploading 
		form_data["$field_name"]="$tmpfile:$filename"
		while read -r upload; do
			echo "$upload" >> "$tmpfile"
		done
	else
		read -r field_value
		form_data["$field_name"]="$field_value"
	fi
	
	return 0
}

# Process multipart form data
formData() {
	array form_data
	
	local boundary=$(echo "$CONTENT_TYPE" | sed -n 's/^.*boundary=\([^;]*\).*$/\1/p')
	
	if [[ -z "$boundary" ]]; then
		return 1
	fi
	
	while IFS= read -r line; do
		# Check multipart boundary
		if [[ "$line" =~ ^--$boundary ]]; then
			read -r line
			
			# Skip file uploads for now
			if [[ "$line" =~ "Content-Disposition:" && "$line" =~ "filename=" ]]; then
				while IFS= read -r fline && [[ ! "$fline" =~ ^--$boundary ]]; do
					continue
				done
				continue
			fi
			formField "$line"
			
			# Something went wrong?
			if [[ $? -ne 0 ]]; then
				break
			fi
		fi
	done <&0
}


# TODO
formatArticle() {
	
}

# TODO
formatEntry() {
	
}

# TODO
archivePage() {
	local uri=$1
	
	# At least year required
	if [ -n "${query[year]}" ]; then
		preamble
		
		# Print year
		echo "Year: ${query[year]}"
		
		if [ -n "${query[month]}" ]; then
			# Month included
			echo "Month: ${query[month]}"
			
			if [ -n "${query[day]}" ]; then
				# Day included
				echo "Day: ${query[day]}"
			fi
		fi
		
		# Page included
		if [ -n "${query[page]}" ]; then
			echo "Page: ${query[page]}"
		fi
		
		exit
	fi	
}

# TODO: Process static article
readArticle() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	echo "Article"
	exit
}

# TODO: Process entry by permalink
readEntry() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	echo "/${query[year]}/${query[month]}/${query[day]}/${query[slug]}"
	exit
}

# TODO: Process search results
searchPage() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	echo "${templates[tpl_noresults]}"
	exit
}

# TODO: Process first few pages
feedPage() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	echo "${templates[tpl_noresults]}"
	exit
}





# Load client request headers
loadRequest

# Basic response filter
filter

# Extract uri segments, if any
requestUri "${request[uri]}"

# Search is present
if [ -n "${query[search]}" ]; then
	searchPage
fi

# Specific page
if [ -n "${query[slug]}" ]; then
	readEntry

# Try to send archive
else
	archivePage
fi

# Exit not captured
sendNotFound

