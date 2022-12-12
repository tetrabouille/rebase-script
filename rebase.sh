#!/bin/bash

GIT_COLOR="#F14E32"
BLUE="#2962FF"
GREEN="#76FF03"
RED="#F44336"

color_text() {
    gum style --foreground "$1" "$2"
}

get_commit() {
    git log --oneline "$1" | gum filter | cut -d' ' -f1
}

get_branches() {
    limit=$1
    exclude=$2

    if [ "$exclude" = "" ];
    then branches=$(git branch --format="%(refname:short)")
    else branches=$(git branch --format="%(refname:short)" | grep -v "$exclude")
    fi

    if [ "$limit" -gt 0 ];
    then gum choose --limit="$limit" $branches
    else gum choose --no-limit $branches
    fi
}

get_branch() {
    get_branches 1 "$1"
}

wait_for_conflicts() {
    conflict_resolved="no"
    conflict=$(git rebase --show-current-patch)
    while [ "$conflict" != "" ];
    do
        echo ""
        echo "$(color_text $BLUE "Conflicts detected, solve them and continue :") "
        fixed=$(gum choose "Continue" "Abort")
        if [ "$fixed" = "Abort" ]; 
        then 
            git rebase --abort
            conflict_resolved="aborted"
        fi
        conflict=$(git rebase --show-current-patch)
    done

    if [ "$conflict_resolved" != "aborted" ];
    then conflict_resolved="yes";
    fi
}

rebased_branches=""

rebase() {
    echo "$(color_text $BLUE "Select branch to update (rebase) :") "
    branch=$(get_branch)
    if [ "$branch" = "" ]; then exit 
    fi
    echo "$(color_text $GREEN "rebasing $branch ...") "
    echo ""    

    echo "$(color_text $BLUE "Select branch with new commits (to rebase on) :") "
    base_branch=$(get_branch "$branch")
    if [ "$base_branch" = "" ]; then exit 
    fi
    echo "$(color_text $GREEN "... on $base_branch") "
    echo ""

    echo "$(color_text $BLUE "Select where to rebase from :") "
    case $(gum choose "From start" "From origin" "From commit") in
        "From start")
            echo "$(color_text $GREEN "from start") "
            commit=""
        ;;
        "From commit")
            commit=$(get_commit "$branch")
            if [ "$commit" = "" ];
            then commit="failed"
            else echo "$(color_text $GREEN "from $commit") "
            fi
            
        ;;
        "From origin")
            commit="origin/$base_branch"
            echo "$(color_text $GREEN "from $commit") "
        ;;
        *)
            exit
        ;;
    esac
    echo ""

    if [ "$commit" != "failed" ];
    then
        if [ "$commit" = "" ];
        then rebase_done=$(git rebase "$base_branch" "$branch" || echo "failed")
        else rebase_done=$(git rebase --onto "$base_branch" "$commit" "$branch" || echo "failed")
        fi

        wait_for_conflicts
        echo ""

        if [ "$rebase_done" != "failed" ] && [ "$conflict_resolved" = "yes" ];
        then 
            if [ "$rebased_branches" = "" ];
            then rebased_branches="$branch"
            elif [[ $rebased_branches != *"$branch"* ]];
            then rebased_branches="$rebased_branches $branch"
            fi
        fi
    fi

    if [ "$rebase_done" = "failed" ];
    then echo "$(color_text $RED "Rebase failed") "
    elif [ "$conflict_resolved" = "aborted" ];
    then echo "$(color_text $RED "Rebase aborted") "
    else echo "$(color_text $GREEN "Rebase successful") "
    fi
    echo ""
}

ask_push() {
    if [ "$rebased_branches" != "" ];
    then 
        gum confirm "$(color_text $BLUE "Push $rebased_branches to origin ?") " && 
        for b in $rebased_branches
        do 
            git checkout "$b" && git push --force-with-lease --no-verify
        done
    fi
}

# main

gum style \
    --border rounded \
    --margin "1" \
    --padding "1 4" \
    --border-foreground $GIT_COLOR \
    "$(color_text $GIT_COLOR Rebase) made easy"

run="yes"
while [ $run = "yes" ];
do
    rebase
    run=$(gum confirm "$(color_text $BLUE "Rebase something else?")" && echo "yes" || echo "no")
    echo ""
done

ask_push
