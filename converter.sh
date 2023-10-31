#!/bin/bash
# safety check
set -euo pipefail

#====================================================		PREP

# start clock
start=$(date +%s.%N)
# get current directory absolute path
rootdir=$(pwd)
# go to /images directory
cd images
# copy directory tree from /images to ~/my_path/media
find . -type d -exec mkdir -p -- "${rootdir}"/media/{} \;
# copy directory tree from /images to ~/my_path/media
find . -type d -exec mkdir -p -- "${rootdir}"/text/{} \;
# renames all images to lowercase and changes underscore to hyphen for all images
find . -type f -exec rename 'y/A-Z_/a-z-/' {} \;
# remove empty lines from all .txt files
find . -type f -name "*.txt" -exec sed -i '/^$/d' {} \;
# remove new line character at the end of every .txt file
find . -type f -name "*.txt" -exec sed -i -z 's/\n$//' {} \;
# aspect ratio function
ar() {
	ident=$(identify "${filename}")
	dimen=$(sed -n '3p' <<< $(sed 's/ /\n/g' <<< "${ident}"))
	iwidth=${dimen%x*}
	iheight=${dimen#*x}
	ar=$(echo "scale=3;"${iwidth}" / "${iheight}"" | bc -l | sed 's/.$//')
	vw=$(echo ""${ar}" * 100" | bc -l | sed 's/...$//')
	#~ ar=$(echo "scale=3;"${iwidth}" / "${iheight}"" | bc -l | sed -e 's/^-\./-0./' -e 's/^\./0./' | sed 's/..$//')
	#~ vw=$(echo ""${ar}" * 100" | bc -l | sed 's/..$//')
	printf "\n"${vw}"/100" >> "${text}"/"${basename}".txt
	printf "\n${vw}" >> "${text}"/"${basename}".txt
}
# ImageMagick temp cache location
#~ export MAGICK_TMPDIR=/home/dux/.cache/protocms
# clean previous cache
#~ rm -rf ${HOME}/.cache/protocms/*

#====================================================		IMAGE CONVERTER

# get absolute paths of /images/ and make readarray/mapfile with it
mapfile -d $'\0' locations < <(find ~+ -type d -print0)
echo
echo -e "\e[00;34mDONE\e[0m" "\e[01;34mimage preparation\e[0m"
echo

for location in "${locations[@]}"; do
	# cd into location
	cd "${location}"
	# store mirrored /media/ location
	media=$(pwd | sed s/images/media/)
	# store mirrored /text/ location
	text=$(pwd | sed s/images/text/)
	# find and copy all work.txt files to /text/ tree
	find . -maxdepth 1 -type f -name "*.txt" -exec cp {} "${text}" \;

	img="$(find . -maxdepth 1 -type f \( -name "*.jpg" -or -name "*.png" \))"
	for filename in $img; do
		# remove metadata
		#~ exiftool -all= "$filename"
		# grab extension and put it in variable
		ext=."${filename##*.}"
		basename=$(basename "${filename}" "${ext}")
		path=$(pwd | sed s/images/media/ | grep -o '/media.*')
		# file width check
		if [[ ! "${filename}" =~ wide ]] ; then
			# NORMAL
			ar
			sizes=(300 400 500 600 700 800 900 1000 1250 1400 1600 1920 2000 2560 3000)
			for size in "${sizes[@]}"; do
				# change jpg ext to webp
				ext=$(sed 's/jpg/webp/' <<<"${ext}")
				file=/"${media}"/"${basename}"_"${size}""${ext}"
				# check if an image already exists
				if ! test -f "${file}"; then
					# check for filetype here
					if [[ "${ext}" =~ webp ]] ; then
						# convert the image and save it in /media/ location
						convert "${location}"/$basename.jpg -colorspace sRGB +dither -interlace JPEG -quality 85 -define webp:lossless=false -define webp:method=6 -strip -resize "${size}" "${media}"/"${basename}"_"${size}".webp &
					else
						convert "${location}"/$basename.png -colorspace sRGB +dither -interlace JPEG -quality 60 -define webp:lossless=false -define webp:method=6 -strip -resize "${size}" "${media}"/"${basename}"_"${size}".webp &
						#~ convert "${location}"/$basename.png -colorspace Gray +dither -interlace PNG -strip -resize "${size}" -depth 4 "${media}"/"${basename}"_"${size}".png &
					fi
				fi
				# compile /media location + name and append it to specific work.txt file in /text/ tree
				path=$(pwd | sed s/images/media/ | grep -o '/media.*')
				#~ printf "\n$path"/"${basename}"_"${size}""${ext}" >> "${text}"/"${basename}".txt
				printf "\n$path"/"${basename}"_"${size}".webp >> "${text}"/"${basename}".txt
			done
			echo -e "\e[00;34mDONE\e[0m" "\e[00;35m${basename}\e[0m"
		else
			# WIDE
			ext=$(sed 's/jpg/webp/' <<<"${ext}")
			file=/"${media}"/"${basename}"_"${size}""${ext}"
			basename=$(basename "${filename}" "${ext}" | sed s/wide-//)
			ar
			sizes=(1000 1250 1400 1600 1920 2560 3000 3500 4000 4500 5000)
			for size in "${sizes[@]}"; do
				if ! test -f "${file}"; then
					if [[ "${ext}" =~ webp ]] ; then
						convert "${location}"/wide-$basename.jpg -colorspace sRGB +dither -interlace JPEG -quality 85 -define webp:lossless=false -define webp:method=6 -strip -resize "${size}" "${media}"/"${basename}"_"${size}".webp &
					else
						convert "${location}"/wide-$basename.png -colorspace sRGB +dither -interlace JPEG -quality 60 -define webp:lossless=false -define webp:method=6 -strip -resize "${size}" "${media}"/"${basename}"_"${size}".webp &
						#~ convert "${location}"/wide-$basename.png -colorspace Gray +dither -interlace PNG -strip -resize "${size}" -depth 4 "${media}"/"${basename}"_"${size}".png &
					fi
				fi
				path=$(pwd | sed s/images/media/ | grep -o '/media.*')
				#~ printf "\n$path"/"${basename}"_"${size}""${ext}" >> "${text}"/"${basename}".txt
				printf "\n$path"/"${basename}"_"${size}".webp >> "${text}"/"${basename}".txt
			done
			echo -e "\e[00;34mDONE\e[0m" "\e[00;36m${basename}\e[0m"
		fi
	done
done
# clean cache
#~ rm -rf ${HOME}/.cache/protocms/*

#====================================================		GLOBAL FUNCTIONS

tab() {
	for (( i=$1; i > 0; i-- )); do echo -n $'\t'; done;
}
spacer() {
	for (( i=$1; i > 0; i-- )); do echo -n '='; done;
}
allsize() {
	# remove everything before and _
	temp=${size#*_}
	# remove everything after and .
	width=${temp%.*}
}
lastsize() {
	temp=${lastsize#*_}
	width=${temp%.*}
}
overlastsize() {
	temp=${overlastsize#*_}
	width=${temp%.*}
}

#====================================================		TXT PREP

# add index nr in front of selected .txt filenames
cd "${rootdir}"/text

mapfile -d $'\0' locations < <(find ~+ -type d -print0)

for location in "${locations[@]}"; do
	cd "${location}"
	textfiles="$(find . -maxdepth 1 -type f -name "*.txt")"
	for textfile in $textfiles; do
		basename=$(basename "${textfile}" .txt)
		if grep -q index= "${textfile}"; then
			index=$(echo $(grep -E "^index=" "${textfile}") | tr -d "index=")
			mv {,"${index}"_}"${basename}".txt
		fi
	done
done
echo
echo -e "\e[00;34mDONE\e[0m" "\e[01;34mtext preparation\e[0m"
echo

#====================================================		HTML GENERAL

# go to general
cd "${rootdir}"/text/general

gen="${rootdir}"/text/general.txt
echo >> "${gen}"

txt="$(find . -maxdepth 1 -type f -name "*.txt")"
for filename in ${txt}; do

	id=$(sed -n '1p' "${filename}")
	alt=$(sed -n '2p' "${filename}")
	#~ ar=$(sed -n '3p' "${filename}")
	# put all lines after 2 line  in an array but exclude last line
	mapfile -t -s 4 sizes < <(sed '$ d' "${filename}")
	# last line of sizes
	lastsize=$(tail -n1 "${filename}")

	# PRINT
	echo "$(tab 3)""<img id=\""${id}"\"" 												>> "${gen}"
	echo "$(tab 4)""src=\"https://jaszewski.art""${sizes[0]}""\"" 			>> "${gen}"
	echo "$(tab 4)""sizes=\"100vw\"" 													>> "${gen}"
	echo "$(tab 4)""srcset=\"" 																>> "${gen}"
	for size in "${sizes[@]}"; do
		allsize
		echo "$(tab 6)""https://jaszewski.art"${size}" "${width}"w," 	>> "${gen}"
	done
	lastsize
	echo "$(tab 6)""https://jaszewski.art"${lastsize}" "${width}"w\"" 	>> "${gen}"
	echo "$(tab 4)"alt="\"${alt}\" loading=\"lazy\">" 							>> "${gen}"
	echo 																								>> "${gen}"

done

#====================================================		HTML SERIES (HOME & GALLERY)

cd "${rootdir}"/text/series

seho="${rootdir}"/text/series-home.txt
gall="${rootdir}"/text/gallery.txt
echo >> "${seho}"
echo >> "${gall}"

# sort array
txt="$(find . -maxdepth 1 -type f -name "*.txt" | sort -n)"
for filename in ${txt}; do

	# local vars
	id=$(sed -n '2p' "${filename}")
	series=$(sed -n '3p' "${filename}")
	bgcol=$(sed -n '4p' "${filename}")
	font=$(sed -n '5p' "${filename}")
	h3=$(sed -n '6p' "${filename}")
	h4=$(sed -n '7p' "${filename}")
	alt=$(sed -n '8p' "${filename}")
	title=$(sed -n '9p' "${filename}")
	titlecure=$(sed -n '10p' "${filename}")

	# prep series overlay
	seov="${rootdir}"/text/series-over/"${filename}"
	overalt=$(sed -n '3p' "${seov}")
	mapfile -t -s 5 oversizes < <(sed '$ d' "${seov}")
	overlastsize=$(tail -n1 "${seov}")

	# prep works
	workdir="${rootdir}"/text/works/"${series}"
	works="$(find "${workdir}" -maxdepth 1 -type f -name "*.txt" | sort -n)"
	#~ echo "${works}"

	mapfile -t -s 12 sizes < <(sed '$ d' "${filename}")
	lastsize=$(tail -n1 "${filename}")

	# PRINT SERIES HOME
	echo "$(tab 5)""<div data-hash=\""${id}"\" class=\"swiper-slide no-select\">"		>> "${seho}"
	echo "$(tab 6)""<a href=\"https://jaszewski.art/gallery#"${id}"\">"						>> "${seho}"
	echo "$(tab 7)""<img src=\"https://jaszewski.art""${sizes[0]}""\"" 						>> "${seho}"
	echo "$(tab 8)""sizes=\"100vw\"" 																			>> "${seho}"
	echo "$(tab 8)""srcset=\"" 																						>> "${seho}"
	for size in "${sizes[@]}"; do
		allsize
		echo "$(tab 10)""https://jaszewski.art"${size}" "${width}"w," 							>> "${seho}"
	done
	lastsize
	echo "$(tab 10)""https://jaszewski.art"${lastsize}" "${width}"w\"" 						>> "${seho}"
	echo "$(tab 8)"alt="\"${alt}\" loading=\"lazy\">" 													>> "${seho}"
	echo "$(tab 7)""<div class=\"gradient-gallery-img\"></div>"								>> "${seho}"
	echo "$(tab 7)""<p class=\"series-name no-select "${font}"\">"${title}"</p>"	>> "${seho}"
	echo "$(tab 6)""</a>"																								>> "${seho}"
	echo "$(tab 5)""</div>"																							>> "${seho}"
	echo 																														>> "${seho}"

	# PRINT SERIES GALLERY
	echo "$(tab 1)""<!--""$(spacer 40)""$titlecure""$(spacer 40)""-->"						>> "${gall}"
	echo 																														>> "${gall}"
	echo "$(tab 2)""<div class=\"scroll-snap\">"															>> "${gall}"
	echo "$(tab 3)""<div class=\"swiper hSwiper\">"													>> "${gall}"
	echo "$(tab 4)""<div class=\"swiper-wrapper\">"													>> "${gall}"
	echo 																														>> "${gall}"
	echo "$(tab 5)""<div id=\""${id}"\" class=\"swiper-slide "${bgcol}"\">"				>> "${gall}"
	echo "$(tab 6)""<h2 class=\"series-name "${font}"\">"${title}"</h2>"				>> "${gall}"
	echo "$(tab 6)""<div class=\"overlay-button noswipe cursor-pointer\" onclick=\"toggOver(event)\"></div>"	>> "${gall}"
	echo "$(tab 6)""<div class=\"overlay overlay-series noswipe overlay-hide\">"		>> "${gall}"
	echo 																														>> "${gall}"
	echo "$(tab 7)""<div class=\"white-background\"></div>"									>> "${gall}"
	echo 																														>> "${gall}"
	echo "$(tab 7)""<div class=\"text-box\">"																>> "${gall}"
	echo "$(tab 8)""<h3 class=\"overlay-series-name\">"${h3}"</h3>"					>> "${gall}"
	echo "$(tab 8)""<h4 class=\"description\">"${h4}"</h4>"									>> "${gall}"
	echo "$(tab 7)""</div>"																							>> "${gall}"
	echo 																														>> "${gall}"
	# print series overlay
	echo "$(tab 7)""<div class=\"image-box\">"															>> "${gall}"
	echo "$(tab 8)""<img src=\"https://jaszewski.art""${oversizes[0]}""\""					>> "${gall}"
	echo "$(tab 8)""sizes=\"100vw\"" 																			>> "${gall}"
	echo "$(tab 8)""srcset=\"" 																						>> "${gall}"
	for size in "${oversizes[@]}"; do
		allsize
		echo "$(tab 10)""https://jaszewski.art"${size}" "${width}"w," 							>> "${gall}"
	done
	overlastsize
	echo "$(tab 10)""https://jaszewski.art"${overlastsize}" "${width}"w\"" 				>> "${gall}"
	echo "$(tab 8)"alt="\"$overalt\" class=\"splash\" loading=\"lazy\">" 					>> "${gall}"
	echo "$(tab 7)""</div>"																							>> "${gall}"
	echo 																														>> "${gall}"
	# print series splash
	echo "$(tab 6)""</div>"																							>> "${gall}"
	echo "$(tab 6)""<img src=\"https://jaszewski.art""${sizes[0]}""\"" 						>> "${gall}"
	echo "$(tab 7)""sizes=\"100vw\"" 																			>> "${gall}"
	echo "$(tab 7)""srcset=\"" 																						>> "${gall}"
	for size in "${sizes[@]}"; do
		allsize
		echo "$(tab 9)""https://jaszewski.art"${size}" "${width}"w," 							>> "${gall}"
	done
	lastsize
	echo "$(tab 9)""https://jaszewski.art"${lastsize}" "${width}"w\"" 							>> "${gall}"
	echo "$(tab 7)""alt="\"${alt}"\" class=\"splash\" loading=\"lazy\">" 						>> "${gall}"
	echo "$(tab 6)""<div class=\"gradient\"></div>"													>> "${gall}"
	echo "$(tab 5)""</div>"																							>> "${gall}"
	echo 																														>> "${gall}"

	# print works
	for work in ${works}; do

		mapfile -t -s 11 wsizes < <(sed '$ d' "${work}")
		lastwsize=$(tail -n1 "${work}")

		wid=$(sed -n '3p' "${work}")
		wbgcol=$(sed -n '4p' "${work}")
		wtitle=$(sed -n '5p' "${work}")
		wtech=$(sed -n '6p' "${work}")
		wyear=$(sed -n '7p' "${work}")
		wdim=$(sed -n '8p' "${work}")
		walt=$(sed -n '9p' "${work}")
		war=$(sed -n '10p' "${work}")
		wvw=$(sed -n '11p' "${work}")

		echo "$(tab 5)""<div id=\""${wid}"\" class=\"swiper-slide "${wbgcol}"\">"				>> "${gall}"
		echo "$(tab 6)""<div class=\"overlay-button noswipe cursor-pointer\" onclick=\"toggOver(event)\"></div>"		>> "${gall}"
		echo "$(tab 6)""<div class=\"overlay overlay-work noswipe overlay-hide\">"			>> "${gall}"
		echo "$(tab 7)""<div class=\"gradient-box\">"															>> "${gall}"
		echo "$(tab 8)""<div class=\"gradient-vertical\"></div>"											>> "${gall}"
		echo "$(tab 7)""</div>"																								>> "${gall}"
		echo "$(tab 7)""<div class=\"white-background\"></div>"										>> "${gall}"
		echo "$(tab 7)""<div class=\"work-box\">"																>> "${gall}"
		echo "$(tab 8)""<p class=\"p-margin-0\"><i>"${wtitle}"</i></p>"							>> "${gall}"
		echo "$(tab 8)""<p class=\"p-margin\">"${wtech}"</p>"											>> "${gall}"
		echo "$(tab 8)""<p class=\"p-margin\">"${wyear}"</p>"										>> "${gall}"
		echo "$(tab 8)""<p class=\"p-margin\">"${wdim}"</p>"											>> "${gall}"
		echo "$(tab 7)""</div>"																								>> "${gall}"
		echo "$(tab 6)""</div>"																								>> "${gall}"
		echo "$(tab 6)""<div class=\"swiper-zoom-container\" data-swiper-zoom=\"6\">"	>> "${gall}"
		echo "$(tab 7)""<img src=\"https://jaszewski.art""${wsizes[0]}""\""							>> "${gall}"
		echo "$(tab 8)""sizes=\"(min-aspect-ratio: "${war}") "${wvw}"vh, 100vw\""			>> "${gall}"
		echo "$(tab 8)""srcset=\""																							>> "${gall}"
		for wsize in "${wsizes[@]}"; do
			temp=${wsize#*_}
			width=${temp%.*}
			echo "$(tab 10)""https://jaszewski.art"${wsize}" "${width}"w," 							>> "${gall}"
		done
		temp=${lastwsize#*_}
		width=${temp%.*}
		echo "$(tab 10)""https://jaszewski.art"${lastwsize}" "${width}"w\"" 						>> "${gall}"
		echo "$(tab 8)""alt=\""${walt}"\" class=\"img-repro\" loading=\"lazy\">"					>> "${gall}"
		echo "$(tab 6)""</div>"																								>> "${gall}"
		echo "$(tab 5)""</div>"																								>> "${gall}"
		echo																															>> "${gall}"
	done

	echo "$(tab 4)""</div>"																									>> "${gall}"
	echo 																																>> "${gall}"
	echo "$(tab 4)""<div class=\"swiper-button-prev glow-red\"></div>"							>> "${gall}"
	echo "$(tab 4)""<div class=\"swiper-button-next glow-red\"></div>"							>> "${gall}"
	echo "$(tab 4)""<div class=\"swiper-pagination\"></div>"											>> "${gall}"
	echo 																																>> "${gall}"
	echo "$(tab 3)""</div>"																									>> "${gall}"
	echo "$(tab 2)""</div>"																									>> "${gall}"
	echo 																																>> "${gall}"

done
echo -e "\e[00;34mDONE\e[0m" "\e[00;36mHTML compilation\e[0m"
echo

#====================================================		TIMER

# compute and display execution time
end=$(date +%s.%N)
echo -e "\e[00;34mDONE in:\e[0m" "\e[00;31m"$(echo "${end}" - "${start}" | bc)" s\e[0m"
echo

#====================================================		END
