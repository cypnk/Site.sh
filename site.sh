#!/bin/sh

# Globals

# Client headers
typeset -A headers

# Form submisisons
typeset -A form_data

# Page request paths
typeset -A archive

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

# Load HTTP headers sent by the visitor
loadHeaders() {
	# Loop through environment variables and extract headers
	for header in $(env | grep -i "HTTP_"); do
		key=$(echo $header | cut -d= -f1 | sed 's/HTTP_//g' | tr 'A-Z' 'a-z' | tr '_' '-')
		value=$(echo $header | cut -d= -f2)
		
		# Store in the associative array
		headers["$key"]="$value"
	done
}

# Static headers
preamble() {
	local code=$1
	local ctype=$2
	
	if ( "$code" = 200 ) {
		echo "Status: 200 OK"
	} elif ( "$code" = 403 ) {
		echo "Status: 403 Forbidden"
	} else {
		echo "Status: 404 Not Found"
	}
	
	if ( "$ctype" = 'text' ) {
		echo "Content-type: text/plain"
	} else {
		echo "Content-type: text/html"
	}
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

# Forbidden page
sendDenied() {
	preamble 403
	echo "${templates[tpl_forbidden]}"
	exit
}

# Load archive array with passed URI parameters
archiveUri() {
	local uri=$1
	
	# Search sent
	archive[search]=$(echo "$uri" | sed -E 's|^/\?search=([^/]+)(/.*)?$|\1|')
	
	# Last, "page" prefixed, string segment
	archive[page]=$(echo "$uri" | sed -E 's|.*/page([1-9][0-9]{0,2})$|\1|')
	
	# Static entry E.G. "about"
	archive[article]=$(echo "$uri" | sed -E 's|^/([a-zA-Z0-9_-\/]{1,255})$|\1|')
	
	# If not searching, try archive
	if [ -z "${archive[search]}" ]; then
		archive[year]=$(echo "$uri" | sed -E 's|^/([0-9]{4})(/.*)?$|\1|')
		archive[month]=$(echo "$uri" | sed -E 's|^/[0-9]{4}/([0-9]{2})(/.*)?$|\1|')
		archive[day]=$(echo "$uri" | sed -E 's|^/[0-9]{4}/[0-9]{2}/([0-9]{2})(/.*)?$|\1|')
	fi
	
	# If not paged path or search, try "slug" string segment
	if [ -z "${archive[page]}" ] && [ -z "${archive[search]}" ]; then
		archive[slug]=$(echo "$uri" | sed -E 's|^/[0-9]{4}/[0-9]{2}/[0-9]{2}/([a-zA-Z0-9_-]{1,255})$|\1|')
	fi
}

# TODO
formatArticle() {
	
}

# TODO
formatEntry() {
	
}

archivePage() {
	local uri=$1
	
	preamble
	
	# At least year required
	if [ -n "${archive[year]}" ]; then
		
		# Print year
		echo "Year: ${archive[year]}"
		
		if [ -n "${archive[month]}" ]; then
			# Month included
			echo "Month: ${archive[month]}"
			
			if [ -n "${archive[day]}" ]; then
				# Day included
				echo "Day: ${archive[day]}"
			fi
		fi
		
		# Page included
		if [ -n "${archive[page]}" ]; then
			echo "Page: ${archive[page]}"
		fi
		
		exit
	fi	
}

readArticle() {
	preamble 200
	# TODO: Process static article
	echo "Article"
	exit
}

readEntry() {
	preamble 200
	# TODO: Process entry by permalink
	echo "/${archive[year]}/${archive[month]}/${archive[day]}/${archive[slug]}"
	exit
}

searchPage() {
	preamble 200
	# TODO: Process search results
	echo "${templates[tpl_noresults]}"
	
	
	exit
}

feedPage() {
	preamble 200
	# TODO: Process first few pages
	echo "${templates[tpl_noresults]}"
	exit
}





# Load client request headers
loadHeaders

# Extract uri segments, if any
archiveUri "${headers[request_uri]}"

# Search is present
if [ -n "${archive[search]}" ]; then
	searchPage
fi

# Specific page
if [ -n "${archive[slug]}" ]; then
	readEntry

# Try to send archive
else
	archivePage
fi

# Exit not captured
sendNotFound

