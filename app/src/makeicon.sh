#!/bin/bash
#
#  makeicon.sh: function for creating app & doc icons
#
#  Copyright (C) 2021  David Marmor
#
#  https://github.com/dmarmor/epichrome
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


# BOOTSTRAP CORE.SH IF NECESSARY

if [[ ! "$coreVersion" ]] ; then
    source "${BASH_SOURCE[0]%/*}/core.sh" 'coreDoInit=1' || exit 1
    [[ "$ok" ]] || abortreport
fi


# MAKEICON: use makeicon.php to build icons
#  makeicon(aIconSource aAppIcon aDocIcon aWelcomeIcon aCrop aCompSize aCompBG aDoProgress aMaxSize aMinSize)
function makeicon {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local aIconSource="$1" ; shift
    local aAppIcon="$1" ; shift
    local aDocIcon="$1" ; shift
    local aWelcomeIcon="$1" ; shift
    local aCrop="$1" ; shift ; [[ "$aCrop" ]] && aCrop='true' || aCrop='false'
    local aCompSize="$1" ; shift
    local aCompBG="$1" ; shift
    local aDoProgress="$1" ; shift
    local aMaxSize="$1" ; shift
    local aMinSize="$1" ; shift
    
    [[ "$aDoProgress" ]] && progress '!stepIconA1'
    
    # makeicon script location
    if [[ ! "$iMakeIconScript" ]] ; then
        local iMakeIconScript="$myScriptPathEpichrome/makeicon.php"
    fi
    if [[ ! -e "$iMakeIconScript" ]] ; then
        ok= ; errmsg="Unable to locate icon creation script."
        errlog
        return 1
    fi
    
    # path to icon templates
    if [[ ! "$iIconTemplatePath" ]] ; then
        local iIconTemplatePath="${myScriptPathEpichrome%/Scripts}/Icons"
    fi
    
    # path to iconset directories
    local iAppIconset="${aAppIcon%.icns}.iconset"
    [[ "$aDocIcon" ]] && local iDocIconset="${aDocIcon%.icns}.iconset"
    
    # delete existing iconsets
    local iExistingIconsets=()
    [[ -e "$iAppIconset" ]] && iExistingIconsets+=( "$iAppIconset" )
    [[ "$aDocIcon" && -d "$iAppIconset" ]] && iExistingIconsets+=( "$iDocIconset" )
    if [[ "${iExistingIconsets[*]}" ]] ; then
        try /bin/rm -rf "${iExistingIconsets[@]}" \
            'Unable to delete existing iconset directories.'
    fi
    
    # create empty iconset directories
    local iNewIconsets=( "$iAppIconset" )
    [[ "$aDocIcon" ]] && iNewIconsets+=( "$iDocIconset" )
    try /bin/mkdir -p "${iNewIconsets[@]}" \
        'Unable to create temporary iconset directories.'
    
    [[ "$ok" ]] || return 1
        
    # set up Big Sur icon comp commands
    if [[ "$aCompSize" ]] ; then
        
        # pre-set comp sizes
        local iAppIconComp_small=0.556640625 # 570x570
        local iAppIconComp_medium=0.69921875 # 716x716
        local iAppIconComp_large=0.8046875   # 824x824
        
        # set comp size
        eval "local iAppIconCompSize=\"\$iAppIconComp_$aCompSize\""
        [[ "$iAppIconCompSize" ]] || iAppIconCompSize="$iAppIconComp_medium"
        
        # set comp background
        local iAppIconCompBGPrefix="$iIconTemplatePath/apptemplate_bg"
        eval "local iAppIconCompBG=\"\${iAppIconCompBGPrefix}_\${aCompBG}.png\""
        if [[ ! -f "$iAppIconCompBG" ]] ; then
            iAppIconCompBG="${iAppIconCompBGPrefix}_white.png"
            if [[ ! -f "$iAppIconCompBG" ]] ; then
                ok= ; errmsg="Unable to find Big Sur icon background ${iAppIconCompBG##*/}."
                errlog
            fi
        fi
        
        # create comp commands
        local iAppIconCompCmd='
        {
            "action": "composite",
            "options": {
                "crop": '"$aCrop"',
                "size": '"$iAppIconCompSize"',
                "clip": true,
                "with": [ {
                    "action": "read",
                    "path": "'"$iAppIconCompBG"'"
                } ]
            }
        },
        {
            "action": "composite",
            "options": {
                "with": [ {
                    "action": "read",
                    "path": "'"$iIconTemplatePath/apptemplate_shadow.png"'"
                } ]
            }
        },'
    else
        
        # don't comp this in any way, just use the straight image
        local iAppIconCompCmd='
        {
            "action": "composite",
            "options": {
                "crop": '"$aCrop"'
            }
        },'
    fi
    
    # build options for icon max & min sizes
    local iSizeLimitCmd=
    if [[ "$aMaxSize" || "$aMinSize" ]] ; then
        local iLimitOpts=()
        [[ "$aMaxSize" ]] && iLimitOpts+=( '"maxSize": '"$aMaxSize" )
        [[ "$aMinSize" ]] && iLimitOpts+=( '"minSize": '"$aMinSize" )
        iSizeLimitCmd=',
                "options": {
                    '"$(join_array ",
                    " "${iLimitOpts[@]}")"'
                }'
    fi
    
    # build doc icon command
    local iDocIconCmd=
    if [[ "$aDocIcon" ]] ; then
        iDocIconCmd=',
        [
            {
                "action": "composite",
                "options": {
                    "crop": '"$aCrop"',
                    "size": 0.5,
                    "ctrY": 0.48828125,
                    "with": [
                        {
                            "action": "read",
                            "path": "'"$iIconTemplatePath/doctemplate_bg.png"'"
                        }
                    ]
                }
            },
            {
                "action": "composite",
                "options": {
                    "compUnder": true,
                    "with": [
                        {
                            "action": "read",
                            "path": "'"$iIconTemplatePath/doctemplate_fg.png"'"
                        }
                    ]
                }
            },
            {
                "action": "write_iconset",
                "path": "'"$iDocIconset"'"'"$iSizeLimitCmd"'
            }
        ]'
    fi
    
    # build final makeicon.php command
    local iMakeIconCmd='
[
    {
        "action": "read",
        "path": "'"$aIconSource"'"
    },
    ['"$iAppIconCompCmd"'
        {
            "action": "write_iconset",
            "path": "'"$iAppIconset"'"'"$iSizeLimitCmd"'
        }
    ]'"$iDocIconCmd"'
]'
    
    # run PHP script to convert image into app (and maybe doc icons)
    local iMakeIconErr=
    try 'iMakeIconErr&=' /usr/bin/php "$iMakeIconScript" "$iMakeIconCmd" ''
    
    if [[ "$ok" ]] ; then
        # convert iconsets to ICNS
        try /usr/bin/iconutil -c icns -o "$aAppIcon" "$iAppIconset" \
            'Unable to create app icon from temporary iconset.'
        [[ "$aDocIcon" ]] &&
            try /usr/bin/iconutil -c icns -o "$aDocIcon" "$iDocIconset" \
                'Unable to create app icon from temporary iconset.'
    else
        # handle messaging for makeicon.php errors
        errmsg="${iMakeIconErr#*PHPERR|}"
        errlog
    fi
    
    [[ "$aDoProgress" ]] && progress 'stepIconA2'
    
    if [[ "$ok" && "$aWelcomeIcon" ]] ; then
        
        # CREATE WELCOME PAGE ICON
        
        # try copying 128x128 icon first
        local iWelcomeIconSrc="$iAppIconset/icon_128x128.png"
        
        if [[ -f "$iWelcomeIconSrc" ]] ; then
            permanent "$iWelcomeIconSrc" "$aWelcomeIcon" \
                'welcome page icon'
        else
            # 128x128 not found, so scale progressively smaller ones
            local curSize
            for curSize in 512 256 64 32 16 ; do
                iWelcomeIconSrc="$iAppIconset/icon_${curSize}x${curSize}.png"
                if [[ -f "$iWelcomeIconSrc" ]] ; then
                    try '!1' /usr/bin/sips --setProperty format png --resampleHeightWidthMax 128 \
                        "$iWelcomeIconSrc" --out "$aWelcomeIcon" \
                        'Unable to create welcome page icon.'
                    break
                fi
                iWelcomeIconSrc=
            done
            if [[ ! "$iWelcomeIconSrc" ]] ; then
                # no size found!
                ok= ; errmsg='Unable to find image to create welcome page icon.'
                errlog
            fi
        fi
        
        # error is nonfatal, we'll just use the default from boilerplate
        if [[ ! "$ok" ]] ; then ok=1 ; errmsg= ; fi
    fi
    
    # destroy iconset directories
    tryalways /bin/rm -rf "${iNewIconsets[@]}" \
        'Unable to remove temporary iconset directories.'
    
    [[ "$aDoProgress" ]] && progress 'stepIconA3'
    
    [[ "$ok" ]] && return 0 || return 1
}
