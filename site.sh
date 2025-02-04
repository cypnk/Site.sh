#!/bin/sh

# Globals

# Client request
typeset -A request

# Page request path properties
typeset -A query

# Form submisisons
typeset -A form_data

# Render templates
typeset -A templates


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



# Functions


# Ternary helper
t() {
	if [ "$1" ]; then
		echo "$2"
	else
		echo "$3"
	fi
}

# Load HTTP request params and headers sent by the visitor
loadRequest() {
	# Loop through environment variables and extract headers
	for request in $(env | grep -i "HTTP_"); do
		key=$(echo $header | cut -d= -f1 | sed 's/HTTP_//g' | tr 'A-Z' 'a-z' | tr '_' '-')
		value=$(echo $header | cut -d= -f2)
		
		# Store in the associative array
		request["$key"]="$value"
	done
	
	# Query params
	request["verb"]=$(echo $REQUEST_METHOD | tr '[:lower:]' '[:upper:]')
	request["uri"]=$REQUEST_URI
}

# Static headers
preamble() {
	local code=$1
	local ctype=$2
	
	if [[ "$code" = 200 ]]; then
		echo "Status: 200 OK"
	elif [[ "$code" = 403 ]]; then
		echo "Status: 403 Forbidden"
	elif [[ "$code" = 405 ]]; then
		echo "Status: 405 Method Not Allowed"
	else
		echo "Status: 404 Not Found"
	fi
	
	if [[ "$ctype" = 'text' ]]; then
		echo "Content-type: text/plain"
	elif [[ "$ctype" = 'none' ]]; then
		# Do nothing
	else
		echo "Content-type: text/html"
	echo
}

# Format HTML templates with placeholder replacement data
render() {
	local $tpl="$1"
	local $out="$tpl"
	
	typeset -A data
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
	preamble 405
	echo "${templates[tpl_nomethod]}"
	exit
}

# Forbidden page
sendDenied() {
	preamble 403
	echo "${templates[tpl_forbidden]}"
	exit
}

# Load archive array with passed URI parameters
requestUri() {
	local uri=$1
	
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

readArticle() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	# TODO: Process static article
	echo "Article"
	exit
}

readEntry() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	# TODO: Process entry by permalink
	echo "/${query[year]}/${query[month]}/${query[day]}/${query[slug]}"
	exit
}

searchPage() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	# TODO: Process search results
	echo "${templates[tpl_noresults]}"
	
	
	exit
}

feedPage() {
	preamble 200
	if [[ "${request["verb"]}" == "head" ]]; then
		exit
	fi
	
	# TODO: Process first few pages
	echo "${templates[tpl_noresults]}"
	exit
}





# Load client request headers
loadRequest

# Limit request methods
if [[ "${request["verb"]}" != "head" && 
	"${request["verb"]}" != "get" && 
	"${request["verb"]}" != "options" ]]; then
	sendNotAllowed
fi


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

