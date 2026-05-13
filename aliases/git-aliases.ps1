# ================================================================
# Git aliases — ported from the oh-my-zsh git plugin
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
#
# Dot-source this file after importing posh-git so wrapper
# aliases can register git tab completion.
# ================================================================

# ---- Remove-Alias polyfill (PS 5.x) ---------------------------
# Remove-Alias became a built-in cmdlet in PowerShell 6.
if ($PSVersionTable.PSVersion.Major -le 5 -and
    -not (Get-Command Remove-Alias -ErrorAction SilentlyContinue)) {
    function Remove-Alias {
        param([string] $Name, [switch] $Force)
        while (Test-Path "Alias:$Name") {
            Remove-Item "Alias:$Name" -Force 2> $null
        }
    }
}

# ---- Shadow built-in PowerShell aliases -----------------------
# Aliases win over functions in PowerShell's command resolution
# order, so these must be cleared before our git functions can
# take over their names.
Remove-Alias gc -Force -ErrorAction SilentlyContinue
Remove-Alias gcb -Force -ErrorAction SilentlyContinue
Remove-Alias gcm -Force -ErrorAction SilentlyContinue
Remove-Alias gcs -Force -ErrorAction SilentlyContinue
Remove-Alias gl -Force -ErrorAction SilentlyContinue
Remove-Alias gm -Force -ErrorAction SilentlyContinue
Remove-Alias gp -Force -ErrorAction SilentlyContinue
Remove-Alias gpv -Force -ErrorAction SilentlyContinue

# ================================================================
# Helpers
# ================================================================

function Get-Git-CurrentBranch {
    git symbolic-ref --quiet HEAD *> $null
    if ($LASTEXITCODE -eq 0) {
        return (git rev-parse --abbrev-ref HEAD)
    }
}

function Get-Git-MainBranch {
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -ne 0) { return }

    foreach ($ref in 'main', 'trunk', 'mainline', 'default', 'stable', 'master') {
        foreach ($prefix in 'refs/heads', 'refs/remotes/origin', 'refs/remotes/upstream') {
            & git show-ref -q --verify "$prefix/$ref"
            if ($LASTEXITCODE -eq 0) { return $ref }
        }
    }

    foreach ($remote in 'origin', 'upstream') {
        $ref = git rev-parse --abbrev-ref "$remote/HEAD" 2> $null
        if ($ref -and $ref -like "$remote/*") {
            return $ref.Substring($remote.Length + 1)
        }
    }

    return 'master'
}

function Get-Git-DevelopBranch {
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -ne 0) { return }

    foreach ($b in 'dev', 'devel', 'develop', 'development') {
        & git show-ref -q --verify "refs/heads/$b"
        if ($LASTEXITCODE -eq 0) { return $b }
    }

    return 'develop'
}

function Write-Host-Deprecated {
    param(
        [Parameter(Mandatory = $true)][string] $previous,
        [Parameter(Mandatory = $true)][string] $next
    )
    Write-Host "[git-aliases] " -ForegroundColor Yellow -NoNewline
    Write-Host "$previous" -ForegroundColor Red -NoNewline
    Write-Host " is a deprecated alias, use " -ForegroundColor Yellow -NoNewline
    Write-Host "`"$next`"" -ForegroundColor Green -NoNewline
    Write-Host " instead.`n" -ForegroundColor Yellow
}

# ================================================================
# Aliases (ordered to match oh-my-zsh README)
# ================================================================

# ---- git ------------------------------------------------------
function g {
    git $args
}

# ---- add ------------------------------------------------------
function ga {
    git add $args
}

function gaa {
    git add --all $args
}

function gapa {
    git add --patch $args
}

function gau {
    git add --update $args
}

function gav {
    git add --verbose $args
}

function gwip {
    git add -A
    $deleted = git ls-files --deleted
    if ($deleted) { git rm $deleted 2> $null }
    git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"
}

# ---- am -------------------------------------------------------
function gam {
    git am $args
}

function gama {
    git am --abort $args
}

function gamc {
    git am --continue $args
}

function gamscp {
    git am --show-current-patch $args
}

function gams {
    git am --skip $args
}

# ---- apply ----------------------------------------------------
function gap {
    git apply $args
}

function gapt {
    git apply --3way $args
}

# ---- bisect ---------------------------------------------------
function gbs {
    git bisect $args
}

function gbsb {
    git bisect bad $args
}

function gbsg {
    git bisect good $args
}

function gbsn {
    git bisect new $args
}

function gbso {
    git bisect old $args
}

function gbsr {
    git bisect reset $args
}

function gbss {
    git bisect start $args
}

# ---- blame ----------------------------------------------------
function gbl {
    git blame -w $args
}

# ---- branch ---------------------------------------------------
function gb {
    git branch $args
}

function gba {
    git branch --all $args
}

function gbd {
    git branch --delete $args
}

function gbd! {
    git branch --delete --force $args
}

function gbda {
    $main = Get-Git-MainBranch
    $dev  = Get-Git-DevelopBranch
    git branch --no-color --merged | ForEach-Object {
        if ($_ -match '^\s*[+*]') { return }  # current or worktree branch
        $name = $_.Trim()
        if (-not $name) { return }
        if ($name -eq $main -or $name -eq $dev) { return }
        git branch --delete $name 2> $null
    }
}

function gbds {
    $defaultBranch = Get-Git-MainBranch
    if (-not $defaultBranch) { $defaultBranch = Get-Git-DevelopBranch }

    git for-each-ref refs/heads/ '--format=%(refname:short)' | ForEach-Object {
        $branch = $_
        $mergeBase = git merge-base $defaultBranch $branch
        if (-not $mergeBase) { return }

        $tree = git rev-parse "$branch^{tree}"
        $syntheticCommit = git commit-tree $tree -p $mergeBase -m _
        $cherry = git cherry $defaultBranch $syntheticCommit
        if ($cherry -match '^-') {
            git branch -D $branch
        }
    }
}

function gbg {
    $previousLang = $env:LANG
    try {
        $env:LANG = 'C'
        git branch -vv | Select-String ': gone\]'
    } finally {
        $env:LANG = $previousLang
    }
}

function gbgd {
    $previousLang = $env:LANG
    try {
        $env:LANG = 'C'
        $branches = git branch --no-color -vv |
            Select-String ': gone\]' |
            ForEach-Object { ($_.Line.Substring(2).Trim() -split '\s+')[0] }
    } finally {
        $env:LANG = $previousLang
    }
    foreach ($b in $branches) { git branch -d $b }
}

function gbgd! {
    $previousLang = $env:LANG
    try {
        $env:LANG = 'C'
        $branches = git branch --no-color -vv |
            Select-String ': gone\]' |
            ForEach-Object { ($_.Line.Substring(2).Trim() -split '\s+')[0] }
    } finally {
        $env:LANG = $previousLang
    }
    foreach ($b in $branches) { git branch -D $b }
}

function gbm {
    git branch --move $args
}

function gbnm {
    git branch --no-merged $args
}

function gbr {
    git branch --remote $args
}

function ggsup {
    $cur = Get-Git-CurrentBranch
    git branch --set-upstream-to=origin/$cur
}

# ---- checkout -------------------------------------------------
function gco {
    git checkout $args
}

function gcor {
    git checkout --recurse-submodules $args
}

function gcb {
    git checkout -b $args
}

function gcb! {
    git checkout -B $args
}

function gcd {
    $dev = Get-Git-DevelopBranch
    git checkout $dev $args
}

function gcm {
    $main = Get-Git-MainBranch
    git checkout $main $args
}

# ---- cherry-pick ----------------------------------------------
function gcp {
    git cherry-pick $args
}

function gcpa {
    git cherry-pick --abort $args
}

function gcpc {
    git cherry-pick --continue $args
}

# ---- clean / clone --------------------------------------------
function gclean {
    git clean --interactive -d $args
}

function gcl {
    git clone --recurse-submodules $args
}

function gclf {
    git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules $args
}

function gclb {
    git clone --bare $args
}

function gccd {
    git clone --recurse-submodules $args
    if ($LASTEXITCODE -ne 0) { return }

    $lastArg = if ($args.Count -gt 0) { $args[-1] } else { $null }
    if ($lastArg -and (Test-Path $lastArg -PathType Container)) {
        Set-Location $lastArg
        return
    }

    foreach ($a in $args) {
        if ($a -match '([^/:]+?)(\.git)?/?$') {
            $dir = $matches[1]
            if (Test-Path $dir -PathType Container) {
                Set-Location $dir
                return
            }
        }
    }
}

# ---- commit ---------------------------------------------------
function gcam {
    git commit --all --message $args
}

function gcas {
    git commit --all --signoff $args
}

function gcasm {
    git commit --all --signoff --message $args
}

function gcs {
    git commit --gpg-sign $args
}

function gcss {
    git commit --gpg-sign --signoff $args
}

function gcssm {
    git commit --gpg-sign --signoff --message $args
}

function gcmsg {
    git commit --message $args
}

function gcsm {
    git commit --signoff --message $args
}

function gc {
    git commit --verbose $args
}

function gca {
    git commit --verbose --all $args
}

function gca! {
    git commit --verbose --all --amend $args
}

function gcan! {
    git commit --verbose --all --no-edit --amend $args
}

function gcans! {
    git commit --verbose --all --signoff --no-edit --amend $args
}

function gcann! {
    git commit --verbose --all --date=now --no-edit --amend $args
}

function gc! {
    git commit --verbose --amend $args
}

function gcn {
    git commit --verbose --no-edit $args
}

function gcn! {
    git commit --verbose --no-edit --amend $args
}

# ---- config / fixup -------------------------------------------
function gcf {
    git config --list $args
}

function gcfu {
    git commit --fixup $args
}

# ---- describe -------------------------------------------------
function gdct {
    $commit = git rev-list --tags --max-count=1
    git describe --tags $commit
}

# ---- diff -----------------------------------------------------
function gd {
    git diff $args
}

function gdca {
    git diff --cached $args
}

function gdcw {
    git diff --cached --word-diff $args
}

function gds {
    git diff --staged $args
}

function gdw {
    git diff --word-diff $args
}

function gdv {
    git diff -w $args
}

function gdup {
    git diff '@{upstream}' $args
}

function gdnolock {
    git diff $args ':(exclude)package-lock.json' ':(exclude)*.lock'
}

function gdt {
    git diff-tree --no-commit-id --name-only -r $args
}

# ---- fetch ----------------------------------------------------
function gf {
    git fetch $args
}

function gfa {
    git fetch --all --tags --prune --jobs=10 $args
}

function gfo {
    git fetch origin $args
}

# ---- gui / help -----------------------------------------------
function gg {
    git gui citool $args
}

function gga {
    git gui citool --amend $args
}

function ghh {
    git help $args
}

# ---- log ------------------------------------------------------
function glgg {
    git log --graph $args
}

function glgga {
    git log --graph --decorate --all $args
}

function glgm {
    git log --graph --max-count=10 $args
}

function glods {
    git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' --date=short $args
}

function glod {
    git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' $args
}

function glola {
    git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all $args
}

function glols {
    git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat $args
}

function glol {
    git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' $args
}

function glo {
    git log --oneline --decorate $args
}

function glog {
    git log --oneline --decorate --graph $args
}

function gloga {
    git log --oneline --decorate --graph --all $args
}

function glp {
    if ($args.Count -ge 1 -and $args[0]) {
        git log --pretty=$args[0]
    }
}

function glg {
    git log --stat $args
}

function glgp {
    git log --stat --patch $args
}

# ---- ls-files -------------------------------------------------
function gignored {
    git ls-files -v | Select-String '^[a-z]' -CaseSensitive
}

function gfg {
    # @args preserved: Select-String is a cmdlet, splatting is required
    # so that flags like -CaseSensitive aren't passed as literal patterns.
    git ls-files | Select-String @args
}

# ---- merge ----------------------------------------------------
function gm {
    git merge $args
}

function gma {
    git merge --abort $args
}

function gmc {
    git merge --continue $args
}

function gms {
    git merge --squash $args
}

function gmff {
    git merge --ff-only $args
}

function gmom {
    $main = Get-Git-MainBranch
    git merge origin/$main $args
}

function gmum {
    $main = Get-Git-MainBranch
    git merge upstream/$main $args
}

function gmtl {
    git mergetool --no-prompt $args
}

function gmtlvim {
    git mergetool --no-prompt --tool=vimdiff $args
}

# ---- pull -----------------------------------------------------
function gl {
    git pull $args
}

function gpr {
    git pull --rebase $args
}

function gprv {
    git pull --rebase -v $args
}

function gpra {
    git pull --rebase --autostash $args
}

function gprav {
    git pull --rebase --autostash -v $args
}

function ggu {
    $b = if ($args.Count -eq 1) { $args[0] } else { Get-Git-CurrentBranch }
    git pull --rebase origin $b
}

function gprom {
    $main = Get-Git-MainBranch
    git pull --rebase origin $main $args
}

function gpromi {
    $main = Get-Git-MainBranch
    git pull --rebase=interactive origin $main $args
}

function gprum {
    $main = Get-Git-MainBranch
    git pull --rebase upstream $main $args
}

function gprumi {
    $main = Get-Git-MainBranch
    git pull --rebase=interactive upstream $main $args
}

function ggpull {
    $cur = Get-Git-CurrentBranch
    git pull origin $cur
}

function ggl {
    if ($args.Count -gt 1) {
        git pull origin $args
    } else {
        $b = if ($args.Count -eq 1) { $args[0] } else { Get-Git-CurrentBranch }
        git pull origin $b
    }
}

function gluc {
    $cur = Get-Git-CurrentBranch
    git pull upstream $cur
}

function glum {
    $main = Get-Git-MainBranch
    git pull upstream $main $args
}

# ---- push -----------------------------------------------------
function gp {
    git push $args
}

function gpd {
    git push --dry-run $args
}

function ggf! {
    $b = if ($args.Count -eq 1) { $args[0] } else { Get-Git-CurrentBranch }
    git push --force origin $b
}

function gpf! {
    git push --force $args
}

function gpf {
    git push --force-with-lease --force-if-includes $args
}

function ggf {
    $b = if ($args.Count -eq 1) { $args[0] } else { Get-Git-CurrentBranch }
    git push --force-with-lease --force-if-includes origin $b
}

function gpsup {
    $cur = Get-Git-CurrentBranch
    git push --set-upstream origin $cur
}

function gpsupf {
    $cur = Get-Git-CurrentBranch
    git push --set-upstream origin $cur --force-with-lease --force-if-includes
}

function gpv {
    git push --verbose $args
}

function gpoat {
    git push origin --all
    if ($LASTEXITCODE -eq 0) { git push origin --tags }
}

function gpo {
    git push origin $args
}

function gpod {
    git push origin --delete $args
}

function gpm {
    git push --mirror $args
}

function ggpush {
    $cur = Get-Git-CurrentBranch
    git push origin $cur
}

function ggp {
    if ($args.Count -gt 1) {
        git push origin $args
    } else {
        $b = if ($args.Count -eq 1) { $args[0] } else { Get-Git-CurrentBranch }
        git push origin $b
    }
}

function ggpnp {
    # @args preserved: ggl and ggp are PowerShell functions, so splatting
    # is required to forward arguments as separate parameters rather than
    # as a single nested array.
    if ($args.Count -eq 0) {
        ggl
        if ($LASTEXITCODE -eq 0) { ggp }
    } else {
        ggl @args
        if ($LASTEXITCODE -eq 0) { ggp @args }
    }
}

function gpu {
    git push upstream $args
}

# ---- rebase ---------------------------------------------------
function grb {
    git rebase $args
}

function grba {
    git rebase --abort $args
}

function grbc {
    git rebase --continue $args
}

function grbi {
    git rebase --interactive $args
}

function grbo {
    git rebase --onto $args
}

function grbs {
    git rebase --skip $args
}

function grbd {
    $dev = Get-Git-DevelopBranch
    git rebase $dev $args
}

function grbm {
    $main = Get-Git-MainBranch
    git rebase $main $args
}

function grbom {
    $main = Get-Git-MainBranch
    git rebase origin/$main $args
}

function grbum {
    $main = Get-Git-MainBranch
    git rebase upstream/$main $args
}

# ---- reflog / remote ------------------------------------------
function grf {
    git reflog $args
}

function gr {
    git remote $args
}

function grv {
    git remote --verbose $args
}

function gra {
    git remote add $args
}

function grrm {
    git remote remove $args
}

function grmv {
    git remote rename $args
}

function grename {
    if ($args.Count -lt 2 -or -not $args[0] -or -not $args[1]) {
        Write-Host "Usage: grename old_branch new_branch"
        return 1
    }

    $oldBranch = $args[0]
    $newBranch = $args[1]
    git branch -m $oldBranch $newBranch
    if ($LASTEXITCODE -ne 0) { return $LASTEXITCODE }

    git push origin ":$oldBranch"
    if ($LASTEXITCODE -eq 0) {
        git push --set-upstream origin $newBranch
    }
}

function grset {
    git remote set-url $args
}

function grup {
    git remote update $args
}

# ---- reset ----------------------------------------------------
function grh {
    git reset $args
}

function gru {
    git reset -- $args
}

function grhh {
    git reset --hard $args
}

function grhk {
    git reset --keep $args
}

function grhs {
    git reset --soft $args
}

function gpristine {
    git reset --hard
    git clean --force -dfx
}

function gwipe {
    git reset --hard
    git clean --force -df
}

function groh {
    $cur = Get-Git-CurrentBranch
    git reset origin/$cur --hard
}

# ---- restore --------------------------------------------------
function grs {
    git restore $args
}

function grss {
    git restore --source $args
}

function grst {
    git restore --staged $args
}

# ---- rev-list / wip -------------------------------------------
function gunwip {
    # Only reset if the last commit is actually a wip commit.
    $lastMsg = git log -n 1 --format='%s' 2> $null
    if ($lastMsg -match '--wip--') {
        git reset HEAD~1
    }
}

function gunwipall {
    $commit = git log --grep='--wip--' --invert-grep --max-count=1 --format='format:%H'
    $head   = git rev-parse HEAD
    if ($commit -and $commit -ne $head) {
        git reset $commit
    }
}

function work_in_progress {
    if (git -c log.showSignature=false log -n 1 2> $null | Select-String -Pattern '--wip--' -Quiet) {
        Write-Output 'WIP!!'
    }
}

# ---- revert ---------------------------------------------------
function grev {
    git revert $args
}

function greva {
    git revert --abort $args
}

function grevc {
    git revert --continue $args
}

# ---- rm -------------------------------------------------------
function grm {
    git rm $args
}

function grmc {
    git rm --cached $args
}

# ---- shortlog / show ------------------------------------------
function gcount {
    git shortlog --summary --numbered $args
}

function gsh {
    git show $args
}

function gsps {
    git show --pretty=short --show-signature $args
}

# ---- stash ----------------------------------------------------
function gstall {
    git stash --all $args
}

function gstaa {
    git stash apply $args
}

function gstc {
    git stash clear $args
}

function gstd {
    git stash drop $args
}

function gstl {
    git stash list $args
}

function gstp {
    git stash pop $args
}

function gsta {
    git stash push $args
}

function gsts {
    git stash show --patch $args
}

function gstu {
    git stash push --include-untracked $args
}

# ---- status ---------------------------------------------------
function gst {
    git status $args
}

function gss {
    git status --short $args
}

function gsb {
    git status --short --branch $args
}

# ---- submodule / svn ------------------------------------------
function gsi {
    git submodule init $args
}

function gsu {
    git submodule update $args
}

function gsd {
    git svn dcommit $args
}

function git-svn-dcommit-push {
    git svn dcommit
    if ($LASTEXITCODE -eq 0) {
        $main = Get-Git-MainBranch
        git push github "${main}:svntrunk"
    }
}

function gsr {
    git svn rebase $args
}

# ---- switch ---------------------------------------------------
function gsw {
    git switch $args
}

function gswc {
    git switch --create $args
}

function gswd {
    $dev = Get-Git-DevelopBranch
    git switch $dev
}

function gswm {
    $main = Get-Git-MainBranch
    git switch $main
}

# ---- tag ------------------------------------------------------
function gta {
    git tag --annotate $args
}

function gts {
    git tag --sign $args
}

function gtv {
    git tag --sort=v:refname
}

function gtl {
    $prefix = if ($args.Count -ge 1) { $args[0] } else { '' }
    git tag --sort=-v:refname -n --list "$prefix*"
}

# ---- update-index ---------------------------------------------
function gignore {
    git update-index --assume-unchanged $args
}

function gunignore {
    git update-index --no-assume-unchanged $args
}

# ---- whatchanged / misc ---------------------------------------
function gwch {
    git log --patch --abbrev-commit --pretty=medium --raw $args
}

function grt {
    $root = git rev-parse --show-toplevel 2> $null
    if (-not $root) { $root = '.' }
    Set-Location $root
}

# ---- gitk -----------------------------------------------------
function gk {
    Start-Process gitk -ArgumentList '--all', '--branches'
}

function gke {
    $walk = git log --walk-reflogs --pretty=%h
    Start-Process gitk -ArgumentList '--all', $walk
}

# ---- worktree -------------------------------------------------
function gwt {
    git worktree $args
}

function gwta {
    git worktree add $args
}

function gwtls {
    git worktree list $args
}

function gwtmv {
    git worktree move $args
}

function gwtrm {
    git worktree remove $args
}

# ---- deprecated -----------------------------------------------
function gup {
    Write-Host-Deprecated 'gup' 'gpr'
    git pull --rebase $args
}

function gupa {
    Write-Host-Deprecated 'gupa' 'gpra'
    git pull --rebase --autostash $args
}

function gupv {
    Write-Host-Deprecated 'gupv' 'gprv'
    git pull --rebase -v $args
}

function ggpur {
    Write-Host-Deprecated 'ggpur' 'ggu'
    ggu @args
}

# ---- git-flow-next -----------------------------------------------
function gfl {
    git flow $args
}

# ---- posh-git tab completion ----------------------------------
if (Get-Command Register-PoshGitAliasFunctions -ErrorAction SilentlyContinue) {
    Register-PoshGitAliasFunctions -Path $PSCommandPath
}
