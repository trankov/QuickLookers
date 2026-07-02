# Аудит листовых UTI расширений (снимок 2026-07-03)

**Дата:** 2026-07-03
**macOS:** 26.5.1 (build 25F80), `sw_vers`
**Утилита:** `Scripts/audit-extension-utis.swift`
**Запуск:** `swift Scripts/audit-extension-utis.swift Sources/QuickLookersEngine/Resources/associations.json`
**Резолвер:** `UTType(filenameExtension:)` из `UniformTypeIdentifiers` — авторитетный источник (не `mdls`, который кеширует).

## Оговорка про чистоту машины

Машина на момент снимка **чистая от сторонних просмотрщиков** (недавно удалён sbarex) — снимок близок к поведению «пользователь без конкурентов». На машинах пользователей со сторонними приложениями (VS Code, JetBrains, Blender, ассемблеры и т. п.) те же расширения могут получить другой листовой UTI — сторонние приложения регистрируют собственные типы через `lsregister`.

**Важное исключение из «чистоты» — найдено в процессе аудита.** Расширение `.nim` резолвится не в `dyn.*` (как ожидалось для языка вне заранее известных системе), а в **`com.quicklookers.nim-source`** — это **собственный UTI самого приложения QuickLookers**, оставшийся зарегистрированным в LaunchServices от более ранней сборки/эксперимента этого же проекта (в текущих исходниках `project.yml`/`Info.plist` такого объявления уже нет — грепом не находится). Проверено:

```
lsregister -dump | grep -B5 "com.quicklookers.nim-source"
→ bundle: QuickLookers (0x3880), uti: com.quicklookers.nim-source
→ QLSupportedContentTypes: ( "com.quicklookers.nim-source", ... )
```

Это артефакт истории разработки самого проекта на этой машине, не факт об экосистеме macOS. **Для решения по `.nim` в следующих задачах эту строку в выводе утилиты игнорировать** — трактовать `.nim` так, как если бы результат был `dyn.*` (собственный UTI, категория 1b), в согласии с ожиданием брифа. Достаточно `pkd -kill` / переустановки / чистой машины, чтобы регистрация исчезла — это не воспроизводимо у пользователей.

Ожидания из брифа (кроме `.nim`) подтвердились:
- `kt`, `kts`, `graphql`, `gql`, `dart`, `zig` → `dyn.*` (1b) — подтверждено.
- `ts` → `public.mpeg-2-transport-stream` (1a) — подтверждено.
- `r` → `com.apple.rez-source` (1a) — подтверждено.

## Полная таблица вывода

Формат: `расширение<TAB>leafUTI<TAB>категория<TAB>→язык`.

```
4dform	dyn.ah62d4rv4ge8xk3dgr73g4	dyn — свой UTI (1b)	→json
4dproject	dyn.ah62d4rv4ge8xk3dusm10y3pdsu	dyn — свой UTI (1b)	→json
6pl	dyn.ah62d4rv4ge8xq6dq	dyn — свой UTI (1b)	→raku
6pm	dyn.ah62d4rv4ge8xq6dr	dyn — свой UTI (1b)	→raku
_coffee	dyn.ah62d4rv4ge8z825tq3xgn3k	dyn — свой UTI (1b)	→coffee
_emacs	dyn.ah62d4rv4ge8z83prqfv1g	dyn — свой UTI (1b)	→emacs-lisp
_js	dyn.ah62d4rv4ge8z84xx	dyn — свой UTI (1b)	→javascript
a51	dyn.ah62d4rv4ge80crmv	dyn — свой UTI (1b)	→asm
abap	dyn.ah62d4rv4ge80c2xbsa	dyn — свой UTI (1b)	→abap
abbrev_defs	dyn.ah62d4rv4ge80c2xcsmw1q15eqzxhg	dyn — свой UTI (1b)	→emacs-lisp
acl	dyn.ah62d4rv4ge80c25q	dyn — свой UTI (1b)	→turtle
ad	dyn.ah62d4rv4ge80c3a	dyn — свой UTI (1b)	→asciidoc
ada	public.ada-source	системный лист — объявить (1a)	→ada
adb	public.ada-source	системный лист — объявить (1a)	→ada
adml	dyn.ah62d4rv4ge80c3drru	dyn — свой UTI (1b)	→xml
admx	dyn.ah62d4rv4ge80c3drta	dyn — свой UTI (1b)	→xml
ado	dyn.ah62d4rv4ge80c3dt	dyn — свой UTI (1b)	→stata
adoc	dyn.ah62d4rv4ge80c3dtqq	dyn — свой UTI (1b)	→asciidoc
adoc.txt	nil	нет типа	→asciidoc
adp	dyn.ah62d4rv4ge80c3du	dyn — свой UTI (1b)	→tcl
ads	public.ada-source	системный лист — объявить (1a)	→ada
al	dyn.ah62d4rv4ge80c5a	dyn — свой UTI (1b)	→perl
ant	dyn.ah62d4rv4ge80c5xy	dyn — свой UTI (1b)	→xml
apacheconf	dyn.ah62d4rv4ge80c6dbqrygn25tr3xa	dyn — свой UTI (1b)	→apache
apex	dyn.ah62d4rv4ge80c6dfta	dyn — свой UTI (1b)	→apex
apl	dyn.ah62d4rv4ge80c6dq	dyn — свой UTI (1b)	→apl
apla	dyn.ah62d4rv4ge80c6dqqe	dyn — свой UTI (1b)	→apl
aplc	dyn.ah62d4rv4ge80c6dqqq	dyn — свой UTI (1b)	→apl
aplf	dyn.ah62d4rv4ge80c6dqq2	dyn — свой UTI (1b)	→apl
apli	dyn.ah62d4rv4ge80c6dqre	dyn — свой UTI (1b)	→apl
apln	dyn.ah62d4rv4ge80c6dqr2	dyn — свой UTI (1b)	→apl
aplo	dyn.ah62d4rv4ge80c6dqr6	dyn — свой UTI (1b)	→apl
app	com.apple.application-file	системный лист — объявить (1a)	→erlang
app.src	nil	нет типа	→erlang
applescript	com.apple.applescript.text	системный лист — объявить (1a)	→applescript
ara	dyn.ah62d4rv4ge80c6xb	dyn — свой UTI (1b)	→ara
as	com.apple.applesingle-archive	системный лист — объявить (1a)	→actionscript-3
asc	dyn.ah62d4rv4ge80c65d	dyn — свой UTI (1b)	→asciidoc
asciidoc	dyn.ah62d4rv4ge80c65drfy0k55d	dyn — свой UTI (1b)	→asciidoc
asd	dyn.ah62d4rv4ge80c65e	dyn — свой UTI (1b)	→common-lisp
asdf	dyn.ah62d4rv4ge80c65eq2	dyn — свой UTI (1b)	→common-lisp
asm	dyn.ah62d4rv4ge80c65r	dyn — свой UTI (1b)	→asm
astro	dyn.ah62d4rv4ge80c65ysm1u	dyn — свой UTI (1b)	→astro
auk	dyn.ah62d4rv4ge80c7pp	dyn — свой UTI (1b)	→awk
aux	dyn.ah62d4rv4ge80c7p2	dyn — свой UTI (1b)	→tex
avsc	dyn.ah62d4rv4ge80c7xxqq	dyn — свой UTI (1b)	→json
aw	dyn.ah62d4rv4ge80c72	dyn — свой UTI (1b)	→php
awk	dyn.ah62d4rv4ge80c75p	dyn — свой UTI (1b)	→awk
axaml	dyn.ah62d4rv4ge80c8dbrz0a	dyn — свой UTI (1b)	→xml
axml	dyn.ah62d4rv4ge80c8drru	dyn — свой UTI (1b)	→xml
bal	dyn.ah62d4rv4ge80e2pq	dyn — свой UTI (1b)	→ballerina
bash	public.bash-script	системный лист — объявить (1a)	→shellscript
bat	dyn.ah62d4rv4ge80e2py	dyn — свой UTI (1b)	→bat
bats	dyn.ah62d4rv4ge80e2pysq	dyn — свой UTI (1b)	→shellscript
bb	dyn.ah62d4rv4ge80e2u	dyn — свой UTI (1b)	→clojure
bbx	dyn.ah62d4rv4ge80e2x2	dyn — свой UTI (1b)	→tex
bdy	dyn.ah62d4rv4ge80e3d3	dyn — свой UTI (1b)	→plsql
be	dyn.ah62d4rv4ge80e3k	dyn — свой UTI (1b)	→berry
beancount	dyn.ah62d4rv4ge80e3pbr3v087pssu	dyn — свой UTI (1b)	→beancount
bib	dyn.ah62d4rv4ge80e4pc	dyn — свой UTI (1b)	→bibtex
bibtex	dyn.ah62d4rv4ge80e4pcsvw1u	dyn — свой UTI (1b)	→bibtex
bicep	dyn.ah62d4rv4ge80e4pdqz2a	dyn — свой UTI (1b)	→bicep
bicepparam	dyn.ah62d4rv4ge80e4pdqz2ha2pwqf0u	dyn — свой UTI (1b)	→bicep
blade	dyn.ah62d4rv4ge80e5dbqvwu	dyn — свой UTI (1b)	→blade
blade.php	nil	нет типа	→blade
bones	dyn.ah62d4rv4ge80e55sqz3u	dyn — свой UTI (1b)	→javascript
boot	dyn.ah62d4rv4ge80e55tsu	dyn — свой UTI (1b)	→clojure
bsl	dyn.ah62d4rv4ge80e65q	dyn — свой UTI (1b)	→bsl
builder	dyn.ah62d4rv4ge80e7pmrvwgn6u	dyn — свой UTI (1b)	→ruby
builds	dyn.ah62d4rv4ge80e7pmrvwhg	dyn — свой UTI (1b)	→xml
c	public.c-source	системный лист — объявить (1a)	→c
c++	public.c-plus-plus-source	системный лист — объявить (1a)	→cpp
cairo	dyn.ah62d4rv4ge80g2pmsm1u	dyn — свой UTI (1b)	→cairo
cake	dyn.ah62d4rv4ge80g2ppqy	dyn — свой UTI (1b)	→coffee
cask	dyn.ah62d4rv4ge80g2pxrq	dyn — свой UTI (1b)	→emacs-lisp
cats	dyn.ah62d4rv4ge80g2pysq	dyn — свой UTI (1b)	→c
cbl	dyn.ah62d4rv4ge80g2xq	dyn — свой UTI (1b)	→cobol
cblcpy	dyn.ah62d4rv4ge80g2xqqr2hw	dyn — свой UTI (1b)	→cobol
cblle	dyn.ah62d4rv4ge80g2xqrvwu	dyn — свой UTI (1b)	→cobol
cblsrce	dyn.ah62d4rv4ge80g2xqsr3gg3k	dyn — свой UTI (1b)	→cobol
cbx	dyn.ah62d4rv4ge80g2x2	dyn — свой UTI (1b)	→tex
cc	public.c-plus-plus-source	системный лист — объявить (1a)	→cpp
ccp	dyn.ah62d4rv4ge80g25u	dyn — свой UTI (1b)	→cobol
ccproj	dyn.ah62d4rv4ge80g25usm10y	dyn — свой UTI (1b)	→xml
ccxml	dyn.ah62d4rv4ge80g252rz0a	dyn — свой UTI (1b)	→xml
cdc	dyn.ah62d4rv4ge80g3dd	dyn — свой UTI (1b)	→cadence
cdf	dyn.ah62d4rv4ge80g3dg	dyn — свой UTI (1b)	→wolfram
cfg	public.toml	системный лист — объявить (1a)	→ini
cgi	dyn.ah62d4rv4ge80g35m	dyn — свой UTI (1b)	→perl
cginc	dyn.ah62d4rv4ge80g35mr3vu	dyn — свой UTI (1b)	→hlsl
cjs	dyn.ah62d4rv4ge80g4xx	dyn — свой UTI (1b)	→javascript
cjsx	dyn.ah62d4rv4ge80g4xxta	dyn — свой UTI (1b)	→coffee
cl	public.opencl-source	системный лист — объявить (1a)	→common-lisp
cl2	dyn.ah62d4rv4ge80g5bw	dyn — свой UTI (1b)	→clojure
clang-format	dyn.ah62d4rv4ge80g5dbr3xw43xtsm00c7a	dyn — свой UTI (1b)	→yaml
clar	dyn.ah62d4rv4ge80g5dbsk	dyn — свой UTI (1b)	→clarity
clixml	dyn.ah62d4rv4ge80g5dmtb002	dyn — свой UTI (1b)	→xml
clj	dyn.ah62d4rv4ge80g5dn	dyn — свой UTI (1b)	→clojure
cljc	dyn.ah62d4rv4ge80g5dnqq	dyn — свой UTI (1b)	→clojure
cljs	dyn.ah62d4rv4ge80g5dnsq	dyn — свой UTI (1b)	→clojure
cljs.hl	nil	нет типа	→clojure
cljscm	dyn.ah62d4rv4ge80g5dnsrv04	dyn — свой UTI (1b)	→clojure
cljx	dyn.ah62d4rv4ge80g5dnta	dyn — свой UTI (1b)	→clojure
cls	dyn.ah62d4rv4ge80g5dx	dyn — свой UTI (1b)	→apex
cmake	dyn.ah62d4rv4ge80g5pbrrwu	dyn — свой UTI (1b)	→cmake
cmake.in	nil	нет типа	→cmake
cmakelists.txt	nil	нет типа	→cmake
cmd	dyn.ah62d4rv4ge80g5pe	dyn — свой UTI (1b)	→bat
cnf	dyn.ah62d4rv4ge80g5xg	dyn — свой UTI (1b)	→ini
cob	dyn.ah62d4rv4ge80g55c	dyn — свой UTI (1b)	→cobol
cobcopy	dyn.ah62d4rv4ge80g55cqr11a8k	dyn — свой UTI (1b)	→cobol
cobol	dyn.ah62d4rv4ge80g55cr70a	dyn — свой UTI (1b)	→cobol
code-snippets	dyn.ah62d4rv4ge80g55eqy01g5xmsb2gn7dx	dyn — свой UTI (1b)	→jsonc
code-workspace	dyn.ah62d4rv4ge80g55eqy01s55wrr31a2pdqy	dyn — свой UTI (1b)	→jsonc
coffee	dyn.ah62d4rv4ge80g55gq3w0n	dyn — свой UTI (1b)	→coffee
command	com.apple.terminal.shell-script	системный лист — объявить (1a)	→shellscript
conf	dyn.ah62d4rv4ge80g55sq2	dyn — свой UTI (1b)	→apache
conf.erb	nil	нет типа	→nginx
copybook	dyn.ah62d4rv4ge80g55utfvg855p	dyn — свой UTI (1b)	→cobol
coq	dyn.ah62d4rv4ge80g55v	dyn — свой UTI (1b)	→coq
cp	public.c-plus-plus-source	системный лист — объявить (1a)	→cpp
cpp	public.c-plus-plus-source	системный лист — объявить (1a)	→cpp
cppm	dyn.ah62d4rv4ge80g6dury	dyn — свой UTI (1b)	→cpp
cproject	dyn.ah62d4rv4ge80g6dwr7zgn25y	dyn — свой UTI (1b)	→xml
cpy	dyn.ah62d4rv4ge80g6d3	dyn — свой UTI (1b)	→cobol
cql	dyn.ah62d4rv4ge80g6pq	dyn — свой UTI (1b)	→cypher
cr	dyn.ah62d4rv4ge80g6u	dyn — свой UTI (1b)	→crystal
cs	dyn.ah62d4rv4ge80g62	dyn — свой UTI (1b)	→csharp
cs.pp	nil	нет типа	→csharp
cscfg	dyn.ah62d4rv4ge80g65dq3xu	dyn — свой UTI (1b)	→xml
csdef	dyn.ah62d4rv4ge80g65eqzxa	dyn — свой UTI (1b)	→xml
cshtml	dyn.ah62d4rv4ge80g65ksv002	dyn — свой UTI (1b)	→razor
csl	dyn.ah62d4rv4ge80g65q	dyn — свой UTI (1b)	→kusto
csproj	dyn.ah62d4rv4ge80g65usm10y	dyn — свой UTI (1b)	→xml
css	public.css	системный лист — объявить (1a)	→css
css.styl	nil	нет типа	→stylus
css.stylus	nil	нет типа	→stylus
csv	public.comma-separated-values-text	системный лист — объявить (1a)	→csv
csx	dyn.ah62d4rv4ge80g652	dyn — свой UTI (1b)	→csharp
ct	dyn.ah62d4rv4ge80g7a	dyn — свой UTI (1b)	→xml
ctp	dyn.ah62d4rv4ge80g7du	dyn — свой UTI (1b)	→php
cts	dyn.ah62d4rv4ge80g7dx	dyn — свой UTI (1b)	→typescript
cue	dyn.ah62d4rv4ge80g7pf	dyn — свой UTI (1b)	→cue
cxx	public.c-plus-plus-source	системный лист — объявить (1a)	→cpp
cyp	dyn.ah62d4rv4ge80g8pu	dyn — свой UTI (1b)	→cypher
cypher	dyn.ah62d4rv4ge80g8purbw1e	dyn — свой UTI (1b)	→cypher
d	dyn.ah62d4rv4ge80k	dyn — свой UTI (1b)	→d
dart	dyn.ah62d4rv4ge80k2pwsu	dyn — свой UTI (1b)	→dart
ddl	dyn.ah62d4rv4ge80k3dq	dyn — свой UTI (1b)	→plsql
dds	com.microsoft.dds	системный лист — объявить (1a)	→cobol
def	dyn.ah62d4rv4ge80k3pg	dyn — свой UTI (1b)	→cobol
depproj	dyn.ah62d4rv4ge80k3pusb3g84u	dyn — свой UTI (1b)	→xml
desktop	dyn.ah62d4rv4ge80k3pxrr4g86a	dyn — свой UTI (1b)	→desktop
desktop.in	nil	нет типа	→desktop
dfm	dyn.ah62d4rv4ge80k3xr	dyn — свой UTI (1b)	→pascal
di	dyn.ah62d4rv4ge80k4k	dyn — свой UTI (1b)	→d
diff	public.patch-file	системный лист — объявить (1a)	→diff
dita	dyn.ah62d4rv4ge80k4pyqe	dyn — свой UTI (1b)	→xml
ditamap	dyn.ah62d4rv4ge80k4pyqf00c6a	dyn — свой UTI (1b)	→xml
ditaval	dyn.ah62d4rv4ge80k4pyqf5gc5a	dyn — свой UTI (1b)	→xml
dll.config	nil	нет типа	→xml
dm	dyn.ah62d4rv4ge80k5k	dyn — свой UTI (1b)	→dream-maker
dme	dyn.ah62d4rv4ge80k5pf	dyn — свой UTI (1b)	→dream-maker
dml	dyn.ah62d4rv4ge80k5pq	dyn — свой UTI (1b)	→plsql
do	dyn.ah62d4rv4ge80k52	dyn — свой UTI (1b)	→stata
dockerfile	dyn.ah62d4rv4ge80k55drrw1e3xmrvwu	dyn — свой UTI (1b)	→docker
dof	dyn.ah62d4rv4ge80k55g	dyn — свой UTI (1b)	→ini
doh	dyn.ah62d4rv4ge80k55k	dyn — свой UTI (1b)	→stata
dotsettings	dyn.ah62d4rv4ge80k55ysrw1k7dmr3x1g	dyn — свой UTI (1b)	→xml
dpk	dyn.ah62d4rv4ge80k6dp	dyn — свой UTI (1b)	→pascal
dpp	dyn.ah62d4rv4ge80k6du	dyn — свой UTI (1b)	→d
dpr	dyn.ah62d4rv4ge80k6dw	dyn — свой UTI (1b)	→pascal
dtx	dyn.ah62d4rv4ge80k7d2	dyn — свой UTI (1b)	→tex
dump	dyn.ah62d4rv4ge80k7prsa	dyn — свой UTI (1b)	→haxe
dyalog	dyn.ah62d4rv4ge80k8pbrv10s	dyn — свой UTI (1b)	→apl
dyapp	dyn.ah62d4rv4ge80k8pbsb2a	dyn — свой UTI (1b)	→apl
edge	dyn.ah62d4rv4ge80n3dhqy	dyn — свой UTI (1b)	→edge
el	dyn.ah62d4rv4ge80n5a	dyn — свой UTI (1b)	→emacs-lisp
elc	dyn.ah62d4rv4ge80n5dd	dyn — свой UTI (1b)	→emacs-lisp
eld	dyn.ah62d4rv4ge80n5de	dyn — свой UTI (1b)	→emacs-lisp
eliom	dyn.ah62d4rv4ge80n5dmr70u	dyn — свой UTI (1b)	→ocaml
eliomi	dyn.ah62d4rv4ge80n5dmr700w	dyn — свой UTI (1b)	→ocaml
elm	dyn.ah62d4rv4ge80n5dr	dyn — свой UTI (1b)	→elm
emacs	dyn.ah62d4rv4ge80n5pbqr3u	dyn — свой UTI (1b)	→emacs-lisp
emacs.desktop	nil	нет типа	→emacs-lisp
env	dyn.ah62d4rv4ge80n5x0	dyn — свой UTI (1b)	→dotenv
envvars	dyn.ah62d4rv4ge80n5x0s3u1e62	dyn — свой UTI (1b)	→apache
erb	dyn.ah62d4rv4ge80n6xc	dyn — свой UTI (1b)	→erb
erb.deface	nil	нет типа	→erb
erl	dyn.ah62d4rv4ge80n6xq	dyn — свой UTI (1b)	→erlang
es	dyn.ah62d4rv4ge80n62	dyn — свой UTI (1b)	→erlang
es6	dyn.ah62d4rv4ge80n630	dyn — свой UTI (1b)	→javascript
escript	dyn.ah62d4rv4ge80n65dsmy1a7a	dyn — свой UTI (1b)	→erlang
ex	dyn.ah62d4rv4ge80n8a	dyn — свой UTI (1b)	→elixir
exs	com.apple.logic.exs	системный лист — объявить (1a)	→elixir
eye	dyn.ah62d4rv4ge80n8pf	dyn — свой UTI (1b)	→ruby
f	public.fortran-source	системный лист — объявить (1a)	→fortran-fixed-form
f.glsl	nil	нет типа	→glsl
f03	dyn.ah62d4rv4ge80qqbx	dyn — свой UTI (1b)	→fortran-free-form
f08	dyn.ah62d4rv4ge80qqb2	dyn — свой UTI (1b)	→fortran-free-form
f18	dyn.ah62d4rv4ge80qqm2	dyn — свой UTI (1b)	→fortran-free-form
f77	public.fortran-77-source	системный лист — объявить (1a)	→fortran-fixed-form
f90	public.fortran-90-source	системный лист — объявить (1a)	→fortran-free-form
f95	public.fortran-95-source	системный лист — объявить (1a)	→fortran-free-form
fastcgi_params	dyn.ah62d4rv4ge80q2pxsvv0s4n9sbu1e2prsq	dyn — свой UTI (1b)	→nginx
fcgi	dyn.ah62d4rv4ge80q25hre	dyn — свой UTI (1b)	→lua
fd	dyn.ah62d4rv4ge80q3a	dyn — свой UTI (1b)	→cobol
feature	dyn.ah62d4rv4ge80q3pbsv41e3k	dyn — свой UTI (1b)	→gherkin
filters	dyn.ah62d4rv4ge80q4pqsvw1e62	dyn — свой UTI (1b)	→xml
fish	dyn.ah62d4rv4ge80q4pxra	dyn — свой UTI (1b)	→fish
fmx	dyn.ah62d4rv4ge80q5p2	dyn — свой UTI (1b)	→pascal
fnc	dyn.ah62d4rv4ge80q5xd	dyn — свой UTI (1b)	→plsql
fnl	dyn.ah62d4rv4ge80q5xq	dyn — свой UTI (1b)	→fennel
for	public.fortran-source	системный лист — объявить (1a)	→fortran-fixed-form
fp	dyn.ah62d4rv4ge80q6a	dyn — свой UTI (1b)	→glsl
fpp	dyn.ah62d4rv4ge80q6du	dyn — свой UTI (1b)	→fortran-free-form
frag	org.khronos.glsl.fragment-shader	системный лист — объявить (1a)	→glsl
frg	dyn.ah62d4rv4ge80q6xh	dyn — свой UTI (1b)	→glsl
fs	org.khronos.glsl.fragment-shader	системный лист — объявить (1a)	→fsharp
fsh	org.khronos.glsl.fragment-shader	системный лист — объявить (1a)	→glsl
fshader	dyn.ah62d4rv4ge80q65kqfwgn6u	dyn — свой UTI (1b)	→glsl
fsi	dyn.ah62d4rv4ge80q65m	dyn — свой UTI (1b)	→fsharp
fsproj	dyn.ah62d4rv4ge80q65usm10y	dyn — свой UTI (1b)	→xml
fst	dyn.ah62d4rv4ge80q65y	dyn — свой UTI (1b)	→fortran-fixed-form
fsti	dyn.ah62d4rv4ge80q65yre	dyn — свой UTI (1b)	→fortran-fixed-form
fsx	dyn.ah62d4rv4ge80q652	dyn — свой UTI (1b)	→fsharp
ftl	dyn.ah62d4rv4ge80q7dq	dyn — свой UTI (1b)	→fluent
fx	dyn.ah62d4rv4ge80q8a	dyn — свой UTI (1b)	→hlsl
fxh	dyn.ah62d4rv4ge80q8dk	dyn — свой UTI (1b)	→hlsl
fxml	dyn.ah62d4rv4ge80q8drru	dyn — свой UTI (1b)	→xml
g.glsl	nil	нет типа	→glsl
gawk	dyn.ah62d4rv4ge80s2p1rq	dyn — свой UTI (1b)	→awk
gd	dyn.ah62d4rv4ge80s3a	dyn — свой UTI (1b)	→gdscript
gdshader	dyn.ah62d4rv4ge80s3dxrbu0k3pw	dyn — свой UTI (1b)	→gdshader
gemspec	dyn.ah62d4rv4ge80s3prsr2gn22	dyn — свой UTI (1b)	→ruby
geo	dyn.ah62d4rv4ge80s3pt	dyn — свой UTI (1b)	→glsl
geojson	public.geojson	системный лист — объявить (1a)	→json
geom	org.khronos.glsl.geometry-shader	системный лист — объявить (1a)	→glsl
gjs	dyn.ah62d4rv4ge80s4xx	dyn — свой UTI (1b)	→glimmer-js
glade	dyn.ah62d4rv4ge80s5dbqvwu	dyn — свой UTI (1b)	→xml
gleam	dyn.ah62d4rv4ge80s5dfqf0u	dyn — свой UTI (1b)	→gleam
glsl	org.khronos.glsl-source	системный лист — объявить (1a)	→glsl
glslf	dyn.ah62d4rv4ge80s5dxrvxa	dyn — свой UTI (1b)	→glsl
glslv	dyn.ah62d4rv4ge80s5dxrv5a	dyn — свой UTI (1b)	→glsl
gml	dyn.ah62d4rv4ge80s5pq	dyn — свой UTI (1b)	→xml
gmx	dyn.ah62d4rv4ge80s5p2	dyn — свой UTI (1b)	→xml
gnu	dyn.ah62d4rv4ge80s5xz	dyn — свой UTI (1b)	→gnuplot
gnuplot	dyn.ah62d4rv4ge80s5xzsb0g87a	dyn — свой UTI (1b)	→gnuplot
gnus	dyn.ah62d4rv4ge80s5xzsq	dyn — свой UTI (1b)	→emacs-lisp
go	dyn.ah62d4rv4ge80s52	dyn — свой UTI (1b)	→go
god	dyn.ah62d4rv4ge80s55e	dyn — свой UTI (1b)	→ruby
gp	com.arobas-music.guitarpro.document	системный лист — объявить (1a)	→gnuplot
gql	dyn.ah62d4rv4ge80s6pq	dyn — свой UTI (1b)	→graphql
graphcool	dyn.ah62d4rv4ge80s6xbsbygg55tru	dyn — свой UTI (1b)	→graphql
graphql	dyn.ah62d4rv4ge80s6xbsbyhc5a	dyn — свой UTI (1b)	→graphql
graphqls	dyn.ah62d4rv4ge80s6xbsbyhc5dx	dyn — свой UTI (1b)	→graphql
groovy	dyn.ah62d4rv4ge80s6xtr75hw	dyn — свой UTI (1b)	→groovy
grt	dyn.ah62d4rv4ge80s6xy	dyn — свой UTI (1b)	→groovy
grxml	dyn.ah62d4rv4ge80s6x2rz0a	dyn — свой UTI (1b)	→xml
gs	org.khronos.glsl.geometry-shader	системный лист — объявить (1a)	→genie
gsh	org.khronos.glsl.geometry-shader	системный лист — объявить (1a)	→glsl
gshader	dyn.ah62d4rv4ge80s65kqfwgn6u	dyn — свой UTI (1b)	→glsl
gst	dyn.ah62d4rv4ge80s65y	dyn — свой UTI (1b)	→xml
gtpl	dyn.ah62d4rv4ge80s7duru	dyn — свой UTI (1b)	→groovy
gts	dyn.ah62d4rv4ge80s7dx	dyn — свой UTI (1b)	→glimmer-ts
gvy	dyn.ah62d4rv4ge80s7x3	dyn — свой UTI (1b)	→groovy
gyp	dyn.ah62d4rv4ge80s8pu	dyn — свой UTI (1b)	→python
gypi	dyn.ah62d4rv4ge80s8pure	dyn — свой UTI (1b)	→python
h	public.c-header	системный лист — объявить (1a)	→c
h++	public.c-plus-plus-header	системный лист — объявить (1a)	→cpp
hack	dyn.ah62d4rv4ge80u2pdrq	dyn — свой UTI (1b)	→hack
haml	dyn.ah62d4rv4ge80u2prru	dyn — свой UTI (1b)	→haml
haml.deface	nil	нет типа	→haml
handlebars	dyn.ah62d4rv4ge80u2psqv0gn2xbsm3u	dyn — свой UTI (1b)	→handlebars
har	dyn.ah62d4rv4ge80u2pw	dyn — свой UTI (1b)	→json
hbs	dyn.ah62d4rv4ge80u2xx	dyn — свой UTI (1b)	→handlebars
hcl	dyn.ah62d4rv4ge80u25q	dyn — свой UTI (1b)	→hcl
hh	public.c-plus-plus-header	системный лист — объявить (1a)	→cpp
hhi	dyn.ah62d4rv4ge80u4dm	dyn — свой UTI (1b)	→hack
hic	dyn.ah62d4rv4ge80u4pd	dyn — свой UTI (1b)	→clojure
hjson	dyn.ah62d4rv4ge80u4xxr71a	dyn — свой UTI (1b)	→hjson
hlean	dyn.ah62d4rv4ge80u5dfqf1a	dyn — свой UTI (1b)	→lean
hlsl	com.microsoft.hlsl	системный лист — объявить (1a)	→hlsl
hlsli	dyn.ah62d4rv4ge80u5dxrvyu	dyn — свой UTI (1b)	→hlsl
hpp	public.c-plus-plus-header	системный лист — объявить (1a)	→cpp
hrl	dyn.ah62d4rv4ge80u6xq	dyn — свой UTI (1b)	→erlang
hs	dyn.ah62d4rv4ge80u62	dyn — свой UTI (1b)	→haskell
hs-boot	dyn.ah62d4rv4ge80u63rqm1087a	dyn — свой UTI (1b)	→haskell
hsc	dyn.ah62d4rv4ge80u65d	dyn — свой UTI (1b)	→haskell
hsig	dyn.ah62d4rv4ge80u65mq6	dyn — свой UTI (1b)	→haskell
hta	dyn.ah62d4rv4ge80u7db	dyn — свой UTI (1b)	→html
htaccess	dyn.ah62d4rv4ge80u7dbqrv0n65x	dyn — свой UTI (1b)	→apache
htgroups	dyn.ah62d4rv4ge80u7dhsm11n6dx	dyn — свой UTI (1b)	→apache
htm	public.html	системный лист — объявить (1a)	→html
html	public.html	системный лист — объявить (1a)	→html
html.erb	nil	нет типа	→erb
html.haml	nil	нет типа	→haml
html.hl	nil	нет типа	→html
html.twig	nil	нет типа	→twig
htpasswd	dyn.ah62d4rv4ge80u7duqf31g75e	dyn — свой UTI (1b)	→apache
http	dyn.ah62d4rv4ge80u7dysa	dyn — свой UTI (1b)	→http
hx	dyn.ah62d4rv4ge80u8a	dyn — свой UTI (1b)	→haxe
hxml	dyn.ah62d4rv4ge80u8drru	dyn — свой UTI (1b)	→hxml
hxsl	dyn.ah62d4rv4ge80u8dxru	dyn — свой UTI (1b)	→haxe
hxx	public.c-plus-plus-header	системный лист — объявить (1a)	→cpp
hy	dyn.ah62d4rv4ge80u8k	dyn — свой UTI (1b)	→hy
hzp	dyn.ah62d4rv4ge80u8xu	dyn — свой UTI (1b)	→xml
i	public.c-source.preprocessed	системный лист — объявить (1a)	→asm
ice	dyn.ah62d4rv4ge80w25f	dyn — свой UTI (1b)	→json
iced	dyn.ah62d4rv4ge80w25fqu	dyn — свой UTI (1b)	→coffee
idc	dyn.ah62d4rv4ge80w3dd	dyn — свой UTI (1b)	→c
ihlp	dyn.ah62d4rv4ge80w4dqsa	dyn — свой UTI (1b)	→stata
imba	dyn.ah62d4rv4ge80w5pcqe	dyn — свой UTI (1b)	→imba
imba2	dyn.ah62d4rv4ge80w5pcqe3a	dyn — свой UTI (1b)	→imba
iml	dyn.ah62d4rv4ge80w5pq	dyn — свой UTI (1b)	→xml
inc	dyn.ah62d4rv4ge80w5xd	dyn — свой UTI (1b)	→asm
ini	com.microsoft.ini	системный лист — объявить (1a)	→ini
inl	public.c-plus-plus-inline-header	системный лист — объявить (1a)	→cpp
ino	dyn.ah62d4rv4ge80w5xt	dyn — свой UTI (1b)	→cpp
ins	dyn.ah62d4rv4ge80w5xx	dyn — свой UTI (1b)	→tex
ipp	public.c-plus-plus-header	системный лист — объявить (1a)	→cpp
ivy	dyn.ah62d4rv4ge80w7x3	dyn — свой UTI (1b)	→xml
ixx	dyn.ah62d4rv4ge80w8d2	dyn — свой UTI (1b)	→cpp
j2	dyn.ah62d4rv4ge80yqu	dyn — свой UTI (1b)	→jinja
jade	dyn.ah62d4rv4ge80y2peqy	dyn — свой UTI (1b)	→pug
jake	dyn.ah62d4rv4ge80y2ppqy	dyn — свой UTI (1b)	→javascript
jav	com.sun.java-source	системный лист — объявить (1a)	→java
java	com.sun.java-source	системный лист — объявить (1a)	→java
javascript	com.netscape.javascript-source	системный лист — объявить (1a)	→javascript
jbuilder	dyn.ah62d4rv4ge80y2xzrf0gk3pw	dyn — свой UTI (1b)	→ruby
jelly	dyn.ah62d4rv4ge80y3pqrv6u	dyn — свой UTI (1b)	→xml
jinja	dyn.ah62d4rv4ge80y4psrmuu	dyn — свой UTI (1b)	→jinja
jinja2	dyn.ah62d4rv4ge80y4psrmuxe	dyn — свой UTI (1b)	→jinja
jison	dyn.ah62d4rv4ge80y4pxr71a	dyn — свой UTI (1b)	→jison
jl	dyn.ah62d4rv4ge80y5a	dyn — свой UTI (1b)	→julia
js	com.netscape.javascript-source	системный лист — объявить (1a)	→javascript
jsb	dyn.ah62d4rv4ge80y65c	dyn — свой UTI (1b)	→javascript
jscad	dyn.ah62d4rv4ge80y65dqfwa	dyn — свой UTI (1b)	→javascript
jsfl	dyn.ah62d4rv4ge80y65gru	dyn — свой UTI (1b)	→javascript
jsh	dyn.ah62d4rv4ge80y65k	dyn — свой UTI (1b)	→java
jslib	dyn.ah62d4rv4ge80y65qrfva	dyn — свой UTI (1b)	→javascript
jsm	dyn.ah62d4rv4ge80y65r	dyn — свой UTI (1b)	→javascript
json	public.json	системный лист — объявить (1a)	→json
json-tmlanguage	public.data	public.data — невод (2)	→json
json5	dyn.ah62d4rv4ge80y65tr24u	dyn — свой UTI (1b)	→json5
jsonc	dyn.ah62d4rv4ge80y65tr3vu	dyn — свой UTI (1b)	→jsonc
jsonl	dyn.ah62d4rv4ge80y65tr30a	dyn — свой UTI (1b)	→json
jsonnet	dyn.ah62d4rv4ge80y65tr31gn7a	dyn — свой UTI (1b)	→jsonnet
jspre	dyn.ah62d4rv4ge80y65usmwu	dyn — свой UTI (1b)	→javascript
jsproj	dyn.ah62d4rv4ge80y65usm10y	dyn — свой UTI (1b)	→xml
jss	dyn.ah62d4rv4ge80y65x	dyn — свой UTI (1b)	→javascript
jssm	dyn.ah62d4rv4ge80y65xry	dyn — свой UTI (1b)	→jssm
jssm_state	dyn.ah62d4rv4ge80y65xrzt1g7dbsvwu	dyn — свой UTI (1b)	→jssm
jsx	dyn.ah62d4rv4ge80y652	dyn — свой UTI (1b)	→jsx
kml	dyn.ah62d4rv4ge8005pq	dyn — свой UTI (1b)	→xml
kojo	dyn.ah62d4rv4ge80055nr6	dyn — свой UTI (1b)	→scala
kql	dyn.ah62d4rv4ge8006pq	dyn — свой UTI (1b)	→kusto
ksh	public.ksh-script	системный лист — объявить (1a)	→shellscript
kt	dyn.ah62d4rv4ge8007a	dyn — свой UTI (1b)	→kotlin
ktm	dyn.ah62d4rv4ge8007dr	dyn — свой UTI (1b)	→kotlin
kts	dyn.ah62d4rv4ge8007dx	dyn — свой UTI (1b)	→kotlin
kusto	dyn.ah62d4rv4ge8007pxsv1u	dyn — свой UTI (1b)	→kusto
l	public.lex-source	системный лист — объявить (1a)	→common-lisp
launch	dyn.ah62d4rv4ge8022pzr3v0u	dyn — свой UTI (1b)	→xml
lbx	dyn.ah62d4rv4ge8022x2	dyn — свой UTI (1b)	→tex
lean	dyn.ah62d4rv4ge8023pbr2	dyn — свой UTI (1b)	→lean
lektorproject	dyn.ah62d4rv4ge8023ppsv11e6dwr7zgn25y	dyn — свой UTI (1b)	→ini
less	dyn.ah62d4rv4ge8023pxsq	dyn — свой UTI (1b)	→less
lfm	dyn.ah62d4rv4ge8023xr	dyn — свой UTI (1b)	→pascal
libsonnet	dyn.ah62d4rv4ge8024pcsr1065xfsu	dyn — свой UTI (1b)	→jsonnet
linq	dyn.ah62d4rv4ge8024psse	dyn — свой UTI (1b)	→csharp
liquid	dyn.ah62d4rv4ge8024pvszy0k	dyn — свой UTI (1b)	→liquid
lisp	dyn.ah62d4rv4ge8024pxsa	dyn — свой UTI (1b)	→common-lisp
livemd	com.fluxmarkdown.livemd	системный лист — объявить (1a)	→markdown
lks	dyn.ah62d4rv4ge80245x	dyn — свой UTI (1b)	→cobol
lmi	dyn.ah62d4rv4ge8025pm	dyn — свой UTI (1b)	→python
log	com.apple.log	системный лист — объявить (1a)	→log
lpr	dyn.ah62d4rv4ge8026dw	dyn — свой UTI (1b)	→pascal
lsp	dyn.ah62d4rv4ge80265u	dyn — свой UTI (1b)	→common-lisp
ltx	dyn.ah62d4rv4ge8027d2	dyn — свой UTI (1b)	→tex
lua	dyn.ah62d4rv4ge8027pb	dyn — свой UTI (1b)	→lua
luau	dyn.ah62d4rv4ge8027pbsy	dyn — свой UTI (1b)	→luau
m	public.objective-c-source	системный лист — объявить (1a)	→objective-c
ma	dyn.ah62d4rv4ge8042k	dyn — свой UTI (1b)	→wolfram
mak	public.make-source	системный лист — объявить (1a)	→make
make	public.make-source	системный лист — объявить (1a)	→make
makefile	dyn.ah62d4rv4ge8042ppqzxgw5df	dyn — свой UTI (1b)	→make
markdown	net.daringfireball.markdown	системный лист — объявить (1a)	→markdown
marko	dyn.ah62d4rv4ge8042pwrr1u	dyn — свой UTI (1b)	→marko
mata	dyn.ah62d4rv4ge8042pyqe	dyn — свой UTI (1b)	→stata
matah	dyn.ah62d4rv4ge8042pyqfya	dyn — свой UTI (1b)	→stata
mathematica	dyn.ah62d4rv4ge8042pyrbw042pyrfv0c	dyn — свой UTI (1b)	→wolfram
matlab	dyn.ah62d4rv4ge8042pyrvu0e	dyn — свой UTI (1b)	→matlab
mawk	dyn.ah62d4rv4ge8042p1rq	dyn — свой UTI (1b)	→awk
mcmeta	dyn.ah62d4rv4ge80425rqz4gc	dyn — свой UTI (1b)	→json
md	net.daringfireball.markdown	системный лист — объявить (1a)	→markdown
mdown	com.fluxmarkdown.mdown	системный лист — объявить (1a)	→markdown
mdpolicy	dyn.ah62d4rv4ge8043dur70gw253	dyn — свой UTI (1b)	→xml
mdwn	com.fluxmarkdown.mdwn	системный лист — объявить (1a)	→markdown
mdx	com.fluxmarkdown.mdx	системный лист — объявить (1a)	→mdx
mediawiki	dyn.ah62d4rv4ge8043perfu1s4ppre	dyn — свой UTI (1b)	→wikitext
mermaid	dyn.ah62d4rv4ge8043pwrzu0w3a	dyn — свой UTI (1b)	→mermaid
mime.types	nil	нет типа	→nginx
mipage	dyn.ah62d4rv4ge8044puqfx0n	dyn — свой UTI (1b)	→apl
mips	dyn.ah62d4rv4ge8044pusq	dyn — свой UTI (1b)	→mipsasm
mir	dyn.ah62d4rv4ge8044pw	dyn — свой UTI (1b)	→yaml
mjml	dyn.ah62d4rv4ge8044xrru	dyn — свой UTI (1b)	→xml
mjs	com.netscape.javascript-source	системный лист — объявить (1a)	→javascript
mk	public.make-source	системный лист — объявить (1a)	→make
mkd	com.fluxmarkdown.mkd	системный лист — объявить (1a)	→markdown
mkdn	com.fluxmarkdown.mkdn	системный лист — объявить (1a)	→markdown
mkdown	com.fluxmarkdown.mkdown	системный лист — объявить (1a)	→markdown
mkfile	dyn.ah62d4rv4ge80445grf0gn	dyn — свой UTI (1b)	→make
mkii	dyn.ah62d4rv4ge80445mre	dyn — свой UTI (1b)	→tex
mkiv	dyn.ah62d4rv4ge80445ms2	dyn — свой UTI (1b)	→tex
mkvi	dyn.ah62d4rv4ge804450re	dyn — свой UTI (1b)	→tex
ml	dyn.ah62d4rv4ge8045a	dyn — свой UTI (1b)	→ocaml
ml4	dyn.ah62d4rv4ge8045by	dyn — свой UTI (1b)	→ocaml
mli	dyn.ah62d4rv4ge8045dm	dyn — свой UTI (1b)	→ocaml
mll	dyn.ah62d4rv4ge8045dq	dyn — свой UTI (1b)	→ocaml
mly	dyn.ah62d4rv4ge8045d3	dyn — свой UTI (1b)	→ocaml
mm	public.objective-c-plus-plus-source	системный лист — объявить (1a)	→objective-cpp
mmd	com.fluxmarkdown.mmd	системный лист — объявить (1a)	→mermaid
mod	org.videolan.mod	системный лист — объявить (1a)	→xml
mojo	dyn.ah62d4rv4ge80455nr6	dyn — свой UTI (1b)	→mojo
move	dyn.ah62d4rv4ge804550qy	dyn — свой UTI (1b)	→move
mspec	dyn.ah62d4rv4ge80465uqzvu	dyn — свой UTI (1b)	→ruby
mt	dyn.ah62d4rv4ge8047a	dyn — свой UTI (1b)	→wolfram
mts	public.avchd-mpeg-2-transport-stream	системный лист — объявить (1a)	→typescript
mxml	dyn.ah62d4rv4ge8048drru	dyn — свой UTI (1b)	→xml
mysql	dyn.ah62d4rv4ge8048pxsf0a	dyn — свой UTI (1b)	→sql
nas	dyn.ah62d4rv4ge8062px	dyn — свой UTI (1b)	→asm
nasm	public.nasm-assembly-source	системный лист — объявить (1a)	→asm
natvis	dyn.ah62d4rv4ge8062pys3y1g	dyn — свой UTI (1b)	→xml
nawk	dyn.ah62d4rv4ge8062p1rq	dyn — свой UTI (1b)	→awk
nb	dyn.ah62d4rv4ge8062u	dyn — свой UTI (1b)	→wolfram
nbp	dyn.ah62d4rv4ge8062xu	dyn — свой UTI (1b)	→wolfram
ncl	dyn.ah62d4rv4ge80625q	dyn — свой UTI (1b)	→xml
ndproj	dyn.ah62d4rv4ge8063dusm10y	dyn — свой UTI (1b)	→xml
nf	dyn.ah62d4rv4ge8063u	dyn — свой UTI (1b)	→nextflow
nginx	dyn.ah62d4rv4ge80635mr36a	dyn — свой UTI (1b)	→nginx
nginx.conf	nil	нет типа	→nginx
nginxconf	dyn.ah62d4rv4ge80635mr36gg55sq2	dyn — свой UTI (1b)	→nginx
ngx	dyn.ah62d4rv4ge806352	dyn — свой UTI (1b)	→nginx
nim	com.quicklookers.nim-source	системный лист — объявить (1a)*	→nim
nim.cfg	nil	нет типа	→nim
nimble	dyn.ah62d4rv4ge8064prqm0gn	dyn — свой UTI (1b)	→nim
nimrod	dyn.ah62d4rv4ge8064prsm10k	dyn — свой UTI (1b)	→nim
nims	dyn.ah62d4rv4ge8064prsq	dyn — свой UTI (1b)	→nim
nix	dyn.ah62d4rv4ge8064p2	dyn — свой UTI (1b)	→nix
njs	dyn.ah62d4rv4ge8064xx	dyn — свой UTI (1b)	→javascript
nomad	dyn.ah62d4rv4ge80655rqfwa	dyn — свой UTI (1b)	→hcl
nproj	dyn.ah62d4rv4ge8066dwr7za	dyn — свой UTI (1b)	→xml
nqp	dyn.ah62d4rv4ge8066pu	dyn — свой UTI (1b)	→raku
nse	dyn.ah62d4rv4ge80665f	dyn — свой UTI (1b)	→lua
nu	dyn.ah62d4rv4ge8067k	dyn — свой UTI (1b)	→nushell
nuspec	dyn.ah62d4rv4ge8067pxsbw0g	dyn — свой UTI (1b)	→xml
ny	dyn.ah62d4rv4ge8068k	dyn — свой UTI (1b)	→common-lisp
odd	dyn.ah62d4rv4ge8083de	dyn — свой UTI (1b)	→xml
os	dyn.ah62d4rv4ge80862	dyn — свой UTI (1b)	→bsl
osm	dyn.ah62d4rv4ge80865r	dyn — свой UTI (1b)	→xml
p	dyn.ah62d4rv4ge81a	dyn — свой UTI (1b)	→pascal
p6	dyn.ah62d4rv4ge81aru	dyn — свой UTI (1b)	→raku
p6l	dyn.ah62d4rv4ge81arxq	dyn — свой UTI (1b)	→raku
p6m	dyn.ah62d4rv4ge81arxr	dyn — свой UTI (1b)	→raku
p8	dyn.ah62d4rv4ge81asa	dyn — свой UTI (1b)	→lua
pac	dyn.ah62d4rv4ge81a2pd	dyn — свой UTI (1b)	→javascript
pas	public.pascal-source	системный лист — объявить (1a)	→pascal
pascal	dyn.ah62d4rv4ge81a2pxqru02	dyn — свой UTI (1b)	→pascal
patch	public.patch-file	системный лист — объявить (1a)	→diff
pck	dyn.ah62d4rv4ge81a25p	dyn — свой UTI (1b)	→plsql
pco	dyn.ah62d4rv4ge81a25t	dyn — свой UTI (1b)	→cobol
pcss	dyn.ah62d4rv4ge81a25xsq	dyn — свой UTI (1b)	→postcss
pd_lua	dyn.ah62d4rv4ge81a3c9rv40c	dyn — свой UTI (1b)	→lua
pdv	dyn.ah62d4rv4ge81a3d0	dyn — свой UTI (1b)	→cobol
perl	dyn.ah62d4rv4ge81a3pwru	dyn — свой UTI (1b)	→perl
pf	com.apple.colorsync-profile	системный лист — объявить (1a)	→fortran-free-form
ph	dyn.ah62d4rv4ge81a4a	dyn — свой UTI (1b)	→perl
php	public.php-script	системный лист — объявить (1a)	→php
php3	public.php-script	системный лист — объявить (1a)	→php
php4	public.php-script	системный лист — объявить (1a)	→php
php5	dyn.ah62d4rv4ge81a4dugy	dyn — свой UTI (1b)	→php
phps	dyn.ah62d4rv4ge81a4dusq	dyn — свой UTI (1b)	→php
phpt	dyn.ah62d4rv4ge81a4dusu	dyn — свой UTI (1b)	→php
pkb	dyn.ah62d4rv4ge81a45c	dyn — свой UTI (1b)	→plsql
pkgproj	dyn.ah62d4rv4ge81a45hsb3g84u	dyn — свой UTI (1b)	→xml
pkh	dyn.ah62d4rv4ge81a45k	dyn — свой UTI (1b)	→plsql
pks	dyn.ah62d4rv4ge81a45x	dyn — свой UTI (1b)	→plsql
pl	public.perl-script	системный лист — объявить (1a)	→perl
pl6	dyn.ah62d4rv4ge81a5b0	dyn — свой UTI (1b)	→raku
plb	dyn.ah62d4rv4ge81a5dc	dyn — свой UTI (1b)	→plsql
plot	dyn.ah62d4rv4ge81a5dtsu	dyn — свой UTI (1b)	→gnuplot
pls	public.pls-playlist	системный лист — объявить (1a)	→plsql
plsql	dyn.ah62d4rv4ge81a5dxsf0a	dyn — свой UTI (1b)	→plsql
plt	dyn.ah62d4rv4ge81a5dy	dyn — свой UTI (1b)	→gnuplot
pluginspec	dyn.ah62d4rv4ge81a5dzq7y0665uqzvu	dyn — свой UTI (1b)	→ruby
plx	dyn.ah62d4rv4ge81a5d2	dyn — свой UTI (1b)	→perl
pm	public.perl-script	системный лист — объявить (1a)	→perl
pm6	dyn.ah62d4rv4ge81a5m0	dyn — свой UTI (1b)	→raku
po	dyn.ah62d4rv4ge81a52	dyn — свой UTI (1b)	→po
podsl	dyn.ah62d4rv4ge81a55esr0a	dyn — свой UTI (1b)	→common-lisp
podspec	dyn.ah62d4rv4ge81a55esr2gn22	dyn — свой UTI (1b)	→ruby
polar	dyn.ah62d4rv4ge81a55qqf3a	dyn — свой UTI (1b)	→polar
postcss	dyn.ah62d4rv4ge81a55xsvv1g62	dyn — свой UTI (1b)	→postcss
pot	com.microsoft.powerpoint.pot	системный лист — объявить (1a)	→po
potx	org.openxmlformats.presentationml.template	системный лист — объявить (1a)	→po
pp	cx.c3.pp-archive	системный лист — объявить (1a)	→pascal
pq	dyn.ah62d4rv4ge81a6k	dyn — свой UTI (1b)	→powerquery
pqm	dyn.ah62d4rv4ge81a6pr	dyn — свой UTI (1b)	→powerquery
prawn	dyn.ah62d4rv4ge81a6xbs71a	dyn — свой UTI (1b)	→ruby
prc	dyn.ah62d4rv4ge81a6xd	dyn — свой UTI (1b)	→plsql
prefs	dyn.ah62d4rv4ge81a6xfq33u	dyn — свой UTI (1b)	→ini
prisma	dyn.ah62d4rv4ge81a6xmsr00c	dyn — свой UTI (1b)	→prisma
pro	dyn.ah62d4rv4ge81a6xt	dyn — свой UTI (1b)	→prolog
proj	dyn.ah62d4rv4ge81a6xtrk	dyn — свой UTI (1b)	→xml
project.ede	nil	нет типа	→emacs-lisp
prolog	dyn.ah62d4rv4ge81a6xtrv10s	dyn — свой UTI (1b)	→prolog
properties	dyn.ah62d4rv4ge81a6xtsbw1e7dmqz3u	dyn — свой UTI (1b)	→ini
props	dyn.ah62d4rv4ge81a6xtsb3u	dyn — свой UTI (1b)	→xml
proto	public.protobuf-source	системный лист — объявить (1a)	→proto
ps1	dyn.ah62d4rv4ge81a63v	dyn — свой UTI (1b)	→powershell
ps1xml	dyn.ah62d4rv4ge81a63vtb002	dyn — свой UTI (1b)	→xml
psc1	dyn.ah62d4rv4ge81a65dge	dyn — свой UTI (1b)	→xml
psd1	dyn.ah62d4rv4ge81a65ege	dyn — свой UTI (1b)	→powershell
psgi	dyn.ah62d4rv4ge81a65hre	dyn — свой UTI (1b)	→perl
psm1	dyn.ah62d4rv4ge81a65rge	dyn — свой UTI (1b)	→powershell
pt	dyn.ah62d4rv4ge81a7a	dyn — свой UTI (1b)	→xml
pug	dyn.ah62d4rv4ge81a7ph	dyn — свой UTI (1b)	→pug
purs	dyn.ah62d4rv4ge81a7pwsq	dyn — свой UTI (1b)	→purescript
py	public.python-script	системный лист — объявить (1a)	→python
py3	dyn.ah62d4rv4ge81a8mx	dyn — свой UTI (1b)	→python
pyde	dyn.ah62d4rv4ge81a8peqy	dyn — свой UTI (1b)	→python
pyi	dyn.ah62d4rv4ge81a8pm	dyn — свой UTI (1b)	→python
pyp	dyn.ah62d4rv4ge81a8pu	dyn — свой UTI (1b)	→python
pyt	dyn.ah62d4rv4ge81a8py	dyn — свой UTI (1b)	→python
pyw	dyn.ah62d4rv4ge81a8p1	dyn — свой UTI (1b)	→python
qbs	dyn.ah62d4rv4ge81c2xx	dyn — свой UTI (1b)	→qml
qhelp	dyn.ah62d4rv4ge81c4dfrv2a	dyn — свой UTI (1b)	→xml
ql	dyn.ah62d4rv4ge81c5a	dyn — свой UTI (1b)	→codeql
qll	dyn.ah62d4rv4ge81c5dq	dyn — свой UTI (1b)	→codeql
qml	dyn.ah62d4rv4ge81c5pq	dyn — свой UTI (1b)	→qml
query	dyn.ah62d4rv4ge81c7pfsm6u	dyn — свой UTI (1b)	→sdbl
r	com.apple.rez-source	системный лист — объявить (1a)	→r
rabl	dyn.ah62d4rv4ge81e2pcru	dyn — свой UTI (1b)	→ruby
rake	dyn.ah62d4rv4ge81e2ppqy	dyn — свой UTI (1b)	→ruby
raku	dyn.ah62d4rv4ge81e2ppsy	dyn — свой UTI (1b)	→raku
rakumod	dyn.ah62d4rv4ge81e2ppsz0083a	dyn — свой UTI (1b)	→raku
razor	dyn.ah62d4rv4ge81e2p4r73a	dyn — свой UTI (1b)	→razor
rb	public.ruby-script	системный лист — объявить (1a)	→ruby
rbi	dyn.ah62d4rv4ge81e2xm	dyn — свой UTI (1b)	→ruby
rbuild	dyn.ah62d4rv4ge81e2xzrf0gk	dyn — свой UTI (1b)	→ruby
rbw	public.ruby-script	системный лист — объявить (1a)	→ruby
rbx	dyn.ah62d4rv4ge81e2x2	dyn — свой UTI (1b)	→ruby
rbxs	dyn.ah62d4rv4ge81e2x2sq	dyn — свой UTI (1b)	→lua
rchit	dyn.ah62d4rv4ge81e25krf4a	dyn — свой UTI (1b)	→glsl
rd	dyn.ah62d4rv4ge81e3a	dyn — свой UTI (1b)	→r
rdf	dyn.ah62d4rv4ge81e3dg	dyn — свой UTI (1b)	→xml
re	dyn.ah62d4rv4ge81e3k	dyn — свой UTI (1b)	→regexp
reek	dyn.ah62d4rv4ge81e3pfrq	dyn — свой UTI (1b)	→yaml
reg	dyn.ah62d4rv4ge81e3ph	dyn — свой UTI (1b)	→reg
regex	dyn.ah62d4rv4ge81e3phqz6a	dyn — свой UTI (1b)	→regexp
regexp	dyn.ah62d4rv4ge81e3phqz6ha	dyn — свой UTI (1b)	→regexp
res	dyn.ah62d4rv4ge81e3px	dyn — свой UTI (1b)	→xml
rest	dyn.ah62d4rv4ge81e3pxsu	dyn — свой UTI (1b)	→http
rest.txt	nil	нет типа	→rst
resx	dyn.ah62d4rv4ge81e3pxta	dyn — свой UTI (1b)	→xml
rhtml	dyn.ah62d4rv4ge81e4dyrz0a	dyn — свой UTI (1b)	→erb
riscv	dyn.ah62d4rv4ge81e4pxqr5a	dyn — свой UTI (1b)	→riscv
rkt	dyn.ah62d4rv4ge81e45y	dyn — свой UTI (1b)	→racket
rktd	dyn.ah62d4rv4ge81e45yqu	dyn — свой UTI (1b)	→racket
rktl	dyn.ah62d4rv4ge81e45yru	dyn — свой UTI (1b)	→racket
rmiss	dyn.ah62d4rv4ge81e5pmsr3u	dyn — свой UTI (1b)	→glsl
rockspec	dyn.ah62d4rv4ge81e55drr31a3pd	dyn — свой UTI (1b)	→lua
ronn	dyn.ah62d4rv4ge81e55sr2	dyn — свой UTI (1b)	→markdown
rpy	dyn.ah62d4rv4ge81e6d3	dyn — свой UTI (1b)	→python
rq	dyn.ah62d4rv4ge81e6k	dyn — свой UTI (1b)	→sparql
rs	dyn.ah62d4rv4ge81e62	dyn — свой UTI (1b)	→rust
rs.in	nil	нет типа	→rust
rss	public.rss	системный лист — объявить (1a)	→xml
rst	dyn.ah62d4rv4ge81e65y	dyn — свой UTI (1b)	→rst
rst.txt	nil	нет типа	→rst
rsx	dyn.ah62d4rv4ge81e652	dyn — свой UTI (1b)	→r
ru	dyn.ah62d4rv4ge81e7k	dyn — свой UTI (1b)	→ruby
ruby	dyn.ah62d4rv4ge81e7pcte	dyn — свой UTI (1b)	→ruby
rviz	dyn.ah62d4rv4ge81e7xmtk	dyn — свой UTI (1b)	→yaml
s	public.assembly-source	системный лист — объявить (1a)	→asm
sarif	dyn.ah62d4rv4ge81g2pwrfxa	dyn — свой UTI (1b)	→json
sas	dyn.ah62d4rv4ge81g2px	dyn — свой UTI (1b)	→sas
sass	dyn.ah62d4rv4ge81g2pxsq	dyn — свой UTI (1b)	→sass
sbt	dyn.ah62d4rv4ge81g2xy	dyn — свой UTI (1b)	→scala
sc	dyn.ah62d4rv4ge81g22	dyn — свой UTI (1b)	→scala
scala	dyn.ah62d4rv4ge81g25brvuu	dyn — свой UTI (1b)	→scala
scb	dyn.ah62d4rv4ge81g25c	dyn — свой UTI (1b)	→cobol
scbl	dyn.ah62d4rv4ge81g25cru	dyn — свой UTI (1b)	→cobol
scd	dyn.ah62d4rv4ge81g25e	dyn — свой UTI (1b)	→markdown
scgi_params	dyn.ah62d4rv4ge81g25hrft1a2pwqf01g	dyn — свой UTI (1b)	→nginx
sch	dyn.ah62d4rv4ge81g25k	dyn — свой UTI (1b)	→scheme
scm	dyn.ah62d4rv4ge81g25r	dyn — свой UTI (1b)	→scheme
scpt	com.apple.applescript.script	системный лист — объявить (1a)	→applescript
scrbl	dyn.ah62d4rv4ge81g25wqm0a	dyn — свой UTI (1b)	→racket
script editor	nil	нет типа	→applescript
scss	dyn.ah62d4rv4ge81g25xsq	dyn — свой UTI (1b)	→scss
scxml	dyn.ah62d4rv4ge81g252rz0a	dyn — свой UTI (1b)	→xml
sdbl	dyn.ah62d4rv4ge81g3dcru	dyn — свой UTI (1b)	→sdbl
sdc	org.openoffice.spreadsheet	системный лист — объявить (1a)	→tcl
sel	dyn.ah62d4rv4ge81g3pq	dyn — свой UTI (1b)	→cobol
service	dyn.ah62d4rv4ge81g3pws3y0g3k	dyn — свой UTI (1b)	→desktop
sexp	dyn.ah62d4rv4ge81g3p2sa	dyn — свой UTI (1b)	→common-lisp
sfproj	dyn.ah62d4rv4ge81g3xusm10y	dyn — свой UTI (1b)	→xml
sh	public.shell-script	системный лист — объявить (1a)	→shellscript
sh-session	dyn.ah62d4rv4ge81g4brsrw1g65mr71a	dyn — свой UTI (1b)	→shellsession
sh.in	nil	нет типа	→shellscript
shader	dyn.ah62d4rv4ge81g4dbqvw1e	dyn — свой UTI (1b)	→glsl
shproj	dyn.ah62d4rv4ge81g4dusm10y	dyn — свой UTI (1b)	→xml
sjs	dyn.ah62d4rv4ge81g4xx	dyn — свой UTI (1b)	→javascript
sld	dyn.ah62d4rv4ge81g5de	dyn — свой UTI (1b)	→scheme
sls	dyn.ah62d4rv4ge81g5dx	dyn — свой UTI (1b)	→scheme
sol	dyn.ah62d4rv4ge81g55q	dyn — свой UTI (1b)	→solidity
soy	dyn.ah62d4rv4ge81g553	dyn — свой UTI (1b)	→soy
spacemacs	dyn.ah62d4rv4ge81g6dbqrw042pdsq	dyn — свой UTI (1b)	→emacs-lisp
sparql	dyn.ah62d4rv4ge81g6dbsm202	dyn — свой UTI (1b)	→sparql
spc	dyn.ah62d4rv4ge81g6dd	dyn — свой UTI (1b)	→plsql
spec	dyn.ah62d4rv4ge81g6dfqq	dyn — свой UTI (1b)	→python
spim	dyn.ah62d4rv4ge81g6dmry	dyn — свой UTI (1b)	→mipsasm
spl	dyn.ah62d4rv4ge81g6dq	dyn — свой UTI (1b)	→splunk
splunk	dyn.ah62d4rv4ge81g6dqsz1g0	dyn — свой UTI (1b)	→splunk
sps	dyn.ah62d4rv4ge81g6dx	dyn — свой UTI (1b)	→scheme
sq	dyn.ah62d4rv4ge81g6k	dyn — свой UTI (1b)	→sparql
sql	org.iso.sql	системный лист — объявить (1a)	→sql
sqlcblle	dyn.ah62d4rv4ge81g6pqqrvg25df	dyn — свой UTI (1b)	→cobol
src	dyn.ah62d4rv4ge81g6xd	dyn — свой UTI (1b)	→cobol
srdf	dyn.ah62d4rv4ge81g6xeq2	dyn — свой UTI (1b)	→xml
ss	dyn.ah62d4rv4ge81g62	dyn — свой UTI (1b)	→cobol
ssh/config	nil	нет типа	→ssh-config
ssh_config	dyn.ah62d4rv4ge81g65kp7v085xgrfxu	dyn — свой UTI (1b)	→ssh-config
sshd_config	dyn.ah62d4rv4ge81g65kqvt0g55sq3y0s	dyn — свой UTI (1b)	→ssh-config
ssjs	dyn.ah62d4rv4ge81g65nsq	dyn — свой UTI (1b)	→javascript
st	dyn.ah62d4rv4ge81g7a	dyn — свой UTI (1b)	→smalltalk
sthlp	dyn.ah62d4rv4ge81g7dkrv2a	dyn — свой UTI (1b)	→stata
story	dyn.ah62d4rv4ge81g7dtsm6u	dyn — свой UTI (1b)	→gherkin
storyboard	com.apple.dt.interfacebuilder.document.storyboard	системный лист — объявить (1a)	→xml
sty	dyn.ah62d4rv4ge81g7d3	dyn — свой UTI (1b)	→tex
styl	dyn.ah62d4rv4ge81g7d3ru	dyn — свой UTI (1b)	→stylus
stylus	dyn.ah62d4rv4ge81g7d3rv41g	dyn — свой UTI (1b)	→stylus
sublime-build	dyn.ah62d4rv4ge81g7pcrvy043mrqm40w5de	dyn — свой UTI (1b)	→jsonc
sublime-color-scheme	dyn.ah62d4rv4ge81g7pcrvy043mrqr10255wfz30g4dfrzwu	dyn — свой UTI (1b)	→jsonc
sublime-commands	dyn.ah62d4rv4ge81g7pcrvy043mrqr1045pbr3whg	dyn — свой UTI (1b)	→jsonc
sublime-completions	dyn.ah62d4rv4ge81g7pcrvy043mrqr1046dqqz4gw55ssq	dyn — свой UTI (1b)	→jsonc
sublime-keymap	dyn.ah62d4rv4ge81g7pcrvy043mrrrw1w5pbsa	dyn — свой UTI (1b)	→jsonc
sublime-macro	dyn.ah62d4rv4ge81g7pcrvy043mrrzu0g6xt	dyn — свой UTI (1b)	→jsonc
sublime-menu	dyn.ah62d4rv4ge81g7pcrvy043mrrzw067k	dyn — свой UTI (1b)	→jsonc
sublime-mousemap	dyn.ah62d4rv4ge81g7pcrvy043mrrz11n65frzu1a	dyn — свой UTI (1b)	→jsonc
sublime-project	dyn.ah62d4rv4ge81g7pcrvy043mrsb3g84xfqr4a	dyn — свой UTI (1b)	→jsonc
sublime-settings	dyn.ah62d4rv4ge81g7pcrvy043mrsrw1k7dmr3x1g	dyn — свой UTI (1b)	→jsonc
sublime-snippet	dyn.ah62d4rv4ge81g7pcrvy043mrsr1gw6duqz4a	dyn — свой UTI (1b)	→xml
sublime-syntax	dyn.ah62d4rv4ge81g7pcrvy043mrsr6067dbta	dyn — свой UTI (1b)	→yaml
sublime-theme	dyn.ah62d4rv4ge81g7pcrvy043mrsvygn5pf	dyn — свой UTI (1b)	→jsonc
sublime-workspace	dyn.ah62d4rv4ge81g7pcrvy043mrs711e45xsbu0g3k	dyn — свой UTI (1b)	→jsonc
sublime_metrics	dyn.ah62d4rv4ge81g7pcrvy043n9rzw1k6xmqr3u	dyn — свой UTI (1b)	→jsonc
sublime_session	dyn.ah62d4rv4ge81g7pcrvy043n9srw1g65mr71a	dyn — свой UTI (1b)	→jsonc
sv	dyn.ah62d4rv4ge81g7u	dyn — свой UTI (1b)	→system-verilog
svelte	dyn.ah62d4rv4ge81g7xfrv4gn	dyn — свой UTI (1b)	→svelte
svh	dyn.ah62d4rv4ge81g7xk	dyn — свой UTI (1b)	→system-verilog
sw	dyn.ah62d4rv4ge81g72	dyn — свой UTI (1b)	→xml
swift	public.swift-source	системный лист — объявить (1a)	→swift
syntax	dyn.ah62d4rv4ge81g8pssvu1u	dyn — свой UTI (1b)	→yaml
t	dyn.ah62d4rv4ge81k	dyn — свой UTI (1b)	→perl
tab	dyn.ah62d4rv4ge81k2pc	dyn — свой UTI (1b)	→tsv
tac	dyn.ah62d4rv4ge81k2pd	dyn — свой UTI (1b)	→python
talon	dyn.ah62d4rv4ge81k2pqr71a	dyn — свой UTI (1b)	→talonscript
targets	dyn.ah62d4rv4ge81k2pwq7w1k62	dyn — свой UTI (1b)	→xml
tasl	dyn.ah62d4rv4ge81k2pxru	dyn — свой UTI (1b)	→tasl
tcc	dyn.ah62d4rv4ge81k25d	dyn — свой UTI (1b)	→cpp
tcl	dyn.ah62d4rv4ge81k25q	dyn — свой UTI (1b)	→tcl
tcl.in	nil	нет типа	→tcl
templ	dyn.ah62d4rv4ge81k3prsb0a	dyn — свой UTI (1b)	→templ
tesc	dyn.ah62d4rv4ge81k3pxqq	dyn — свой UTI (1b)	→glsl
tese	dyn.ah62d4rv4ge81k3pxqy	dyn — свой UTI (1b)	→glsl
tex	dyn.ah62d4rv4ge81k3p2	dyn — свой UTI (1b)	→tex
tf	dyn.ah62d4rv4ge81k3u	dyn — свой UTI (1b)	→terraform
tfstate	dyn.ah62d4rv4ge81k3xxsvu1k3k	dyn — свой UTI (1b)	→json
tfstate.backup	nil	нет типа	→json
tfvars	dyn.ah62d4rv4ge81k3x0qf3hg	dyn — свой UTI (1b)	→terraform
thor	dyn.ah62d4rv4ge81k4dtsk	dyn — свой UTI (1b)	→ruby
tm	dyn.ah62d4rv4ge81k5k	dyn — свой UTI (1b)	→tcl
tml	dyn.ah62d4rv4ge81k5pq	dyn — свой UTI (1b)	→xml
tmux	dyn.ah62d4rv4ge81k5pzta	dyn — свой UTI (1b)	→shellscript
toc	dyn.ah62d4rv4ge81k55d	dyn — свой UTI (1b)	→tex
toml	public.toml	системный лист — объявить (1a)	→toml
tool	com.apple.terminal.shell-script	системный лист — объявить (1a)	→shellscript
topojson	dyn.ah62d4rv4ge81k55ur7zhg55s	dyn — свой UTI (1b)	→json
tpb	dyn.ah62d4rv4ge81k6dc	dyn — свой UTI (1b)	→plsql
tpp	dyn.ah62d4rv4ge81k6du	dyn — свой UTI (1b)	→cpp
tps	dyn.ah62d4rv4ge81k6dx	dyn — свой UTI (1b)	→plsql
trg	dyn.ah62d4rv4ge81k6xh	dyn — свой UTI (1b)	→plsql
trigger	dyn.ah62d4rv4ge81k6xmq7x0n6u	dyn — свой UTI (1b)	→apex
ts	public.mpeg-2-transport-stream	системный лист — объявить (1a)	→typescript
tsp	dyn.ah62d4rv4ge81k65u	dyn — свой UTI (1b)	→typespec
tsv	public.tab-separated-values-text	системный лист — объявить (1a)	→tsv
tsx	com.microsoft.typescript	системный лист — объявить (1a)	→tsx
ttl	dyn.ah62d4rv4ge81k7dq	dyn — свой UTI (1b)	→turtle
turtle	dyn.ah62d4rv4ge81k7pwsv0gn	dyn — свой UTI (1b)	→turtle
twig	dyn.ah62d4rv4ge81k75mq6	dyn — свой UTI (1b)	→twig
txx	dyn.ah62d4rv4ge81k8d2	dyn — свой UTI (1b)	→cpp
typ	dyn.ah62d4rv4ge81k8pu	dyn — свой UTI (1b)	→typst
udf	dyn.ah62d4rv4ge81n3dg	dyn — свой UTI (1b)	→sql
ui	dyn.ah62d4rv4ge81n4k	dyn — свой UTI (1b)	→xml
urdf	dyn.ah62d4rv4ge81n6xeq2	dyn — свой UTI (1b)	→xml
url	com.microsoft.internet-shortcut	системный лист — объявить (1a)	→ini
uwsgi_params	dyn.ah62d4rv4ge81n75xq7yz86dbsmu0462	dyn — свой UTI (1b)	→nginx
ux	dyn.ah62d4rv4ge81n8a	dyn — свой UTI (1b)	→xml
v	dyn.ah62d4rv4ge81q	dyn — свой UTI (1b)	→coq
v.glsl	nil	нет типа	→glsl
v.mod	nil	нет типа	→v
vala	dyn.ah62d4rv4ge81q2pqqe	dyn — свой UTI (1b)	→vala
vapi	dyn.ah62d4rv4ge81q2pure	dyn — свой UTI (1b)	→vala
vb	dyn.ah62d4rv4ge81q2u	dyn — свой UTI (1b)	→vb
vba	dyn.ah62d4rv4ge81q2xb	dyn — свой UTI (1b)	→viml
vbhtml	dyn.ah62d4rv4ge81q2xksv002	dyn — свой UTI (1b)	→vb
vbproj	dyn.ah62d4rv4ge81q2xusm10y	dyn — свой UTI (1b)	→xml
vcxproj	dyn.ah62d4rv4ge81q252sb3g84u	dyn — свой UTI (1b)	→xml
veo	dyn.ah62d4rv4ge81q3pt	dyn — свой UTI (1b)	→verilog
vert	org.khronos.glsl.vertex-shader	системный лист — объявить (1a)	→glsl
vh	dyn.ah62d4rv4ge81q4a	dyn — свой UTI (1b)	→system-verilog
vhd	dyn.ah62d4rv4ge81q4de	dyn — свой UTI (1b)	→vhdl
vhdl	dyn.ah62d4rv4ge81q4deru	dyn — свой UTI (1b)	→vhdl
vhf	dyn.ah62d4rv4ge81q4dg	dyn — свой UTI (1b)	→vhdl
vhi	dyn.ah62d4rv4ge81q4dm	dyn — свой UTI (1b)	→vhdl
vho	dyn.ah62d4rv4ge81q4dt	dyn — свой UTI (1b)	→vhdl
vhost	dyn.ah62d4rv4ge81q4dtsr4a	dyn — свой UTI (1b)	→apache
vhs	dyn.ah62d4rv4ge81q4dx	dyn — свой UTI (1b)	→vhdl
vht	dyn.ah62d4rv4ge81q4dy	dyn — свой UTI (1b)	→vhdl
vhw	dyn.ah62d4rv4ge81q4d1	dyn — свой UTI (1b)	→vhdl
vim	dyn.ah62d4rv4ge81q4pr	dyn — свой UTI (1b)	→viml
vimrc	dyn.ah62d4rv4ge81q4prsmvu	dyn — свой UTI (1b)	→viml
viper	dyn.ah62d4rv4ge81q4puqz3a	dyn — свой UTI (1b)	→emacs-lisp
viw	dyn.ah62d4rv4ge81q4p1	dyn — свой UTI (1b)	→sql
vmb	dyn.ah62d4rv4ge81q5pc	dyn — свой UTI (1b)	→viml
vrx	dyn.ah62d4rv4ge81q6x2	dyn — свой UTI (1b)	→glsl
vs	org.khronos.glsl.vertex-shader	системный лист — объявить (1a)	→glsl
vsh	org.khronos.glsl.vertex-shader	системный лист — объявить (1a)	→glsl
vshader	dyn.ah62d4rv4ge81q65kqfwgn6u	dyn — свой UTI (1b)	→glsl
vsixmanifest	dyn.ah62d4rv4ge81q65mtb00c5xmq3w1g7a	dyn — свой UTI (1b)	→xml
vssettings	dyn.ah62d4rv4ge81q65xqz4hk4psq73u	dyn — свой UTI (1b)	→xml
vstemplate	dyn.ah62d4rv4ge81q65yqz01a5dbsvwu	dyn — свой UTI (1b)	→xml
vue	dyn.ah62d4rv4ge81q7pf	dyn — свой UTI (1b)	→vue
vv	dyn.ah62d4rv4ge81q7u	dyn — свой UTI (1b)	→v
vw	dyn.ah62d4rv4ge81q72	dyn — свой UTI (1b)	→plsql
vxml	dyn.ah62d4rv4ge81q8drru	dyn — свой UTI (1b)	→xml
vy	dyn.ah62d4rv4ge81q8k	dyn — свой UTI (1b)	→vyper
wast	dyn.ah62d4rv4ge81s2pxsu	dyn — свой UTI (1b)	→wasm
wat	dyn.ah62d4rv4ge81s2py	dyn — свой UTI (1b)	→wasm
watchr	dyn.ah62d4rv4ge81s2pyqryhe	dyn — свой UTI (1b)	→ruby
webapp	dyn.ah62d4rv4ge81s3pcqf2ha	dyn — свой UTI (1b)	→json
webmanifest	dyn.ah62d4rv4ge81s3pcrzu064pgqz31k	dyn — свой UTI (1b)	→json
wgsl	dyn.ah62d4rv4ge81s35xru	dyn — свой UTI (1b)	→wgsl
wiki	dyn.ah62d4rv4ge81s4ppre	dyn — свой UTI (1b)	→wikitext
wikitext	dyn.ah62d4rv4ge81s4pprf4gn8dy	dyn — свой UTI (1b)	→wikitext
wixproj	dyn.ah62d4rv4ge81s4p2sb3g84u	dyn — свой UTI (1b)	→xml
wks	dyn.ah62d4rv4ge81s45x	dyn — свой UTI (1b)	→cobol
wl	dyn.ah62d4rv4ge81s5a	dyn — свой UTI (1b)	→wolfram
wls	dyn.ah62d4rv4ge81s5dx	dyn — свой UTI (1b)	→wolfram
wlt	dyn.ah62d4rv4ge81s5dy	dyn — свой UTI (1b)	→wolfram
wlua	dyn.ah62d4rv4ge81s5dzqe	dyn — свой UTI (1b)	→lua
workbook	dyn.ah62d4rv4ge81s55wrrvg855p	dyn — свой UTI (1b)	→markdown
workflow	dyn.ah62d4rv4ge81s55wrrxg2551	dyn — свой UTI (1b)	→hcl
wsdl	dyn.ah62d4rv4ge81s65eru	dyn — свой UTI (1b)	→xml
wsf	dyn.ah62d4rv4ge81s65g	dyn — свой UTI (1b)	→xml
wsgi	dyn.ah62d4rv4ge81s65hre	dyn — свой UTI (1b)	→python
wxi	dyn.ah62d4rv4ge81s8dm	dyn — свой UTI (1b)	→xml
wxl	dyn.ah62d4rv4ge81s8dq	dyn — свой UTI (1b)	→xml
wxs	dyn.ah62d4rv4ge81s8dx	dyn — свой UTI (1b)	→xml
x3d	dyn.ah62d4rv4ge81uq5e	dyn — свой UTI (1b)	→xml
xacro	dyn.ah62d4rv4ge81u2pdsm1u	dyn — свой UTI (1b)	→xml
xaml	dyn.ah62d4rv4ge81u2prru	dyn — свой UTI (1b)	→xml
xdc	dyn.ah62d4rv4ge81u3dd	dyn — свой UTI (1b)	→tcl
xht	public.xhtml	системный лист — объявить (1a)	→html
xhtml	public.xhtml	системный лист — объявить (1a)	→html
xib	com.apple.interfacebuilder.document.cocoa	системный лист — объявить (1a)	→xml
xlf	org.oasis-open.xliff	системный лист — объявить (1a)	→xml
xliff	org.oasis-open.xliff	системный лист — объявить (1a)	→xml
xmi	dyn.ah62d4rv4ge81u5pm	dyn — свой UTI (1b)	→xml
xml	public.xml	системный лист — объявить (1a)	→xml
xml.dist	nil	нет типа	→xml
xmp	com.seriflabs.xmp	системный лист — объявить (1a)	→xml
xproj	dyn.ah62d4rv4ge81u6dwr7za	dyn — свой UTI (1b)	→xml
xpy	dyn.ah62d4rv4ge81u6d3	dyn — свой UTI (1b)	→python
xrl	dyn.ah62d4rv4ge81u6xq	dyn — свой UTI (1b)	→erlang
xsd	dyn.ah62d4rv4ge81u65e	dyn — свой UTI (1b)	→xml
xsjs	dyn.ah62d4rv4ge81u65nsq	dyn — свой UTI (1b)	→javascript
xsjslib	dyn.ah62d4rv4ge81u65nsr0gw2u	dyn — свой UTI (1b)	→javascript
xsl	dyn.ah62d4rv4ge81u65q	dyn — свой UTI (1b)	→xsl
xslt	dyn.ah62d4rv4ge81u65qsu	dyn — свой UTI (1b)	→xsl
xspec	dyn.ah62d4rv4ge81u65uqzvu	dyn — свой UTI (1b)	→xml
xul	dyn.ah62d4rv4ge81u7pq	dyn — свой UTI (1b)	→xml
yaml	public.yaml	системный лист — объявить (1a)	→yaml
yaml-tmlanguage	public.data	public.data — невод (2)	→yaml
yaml.sed	nil	нет типа	→yaml
yap	dyn.ah62d4rv4ge81w2pu	dyn — свой UTI (1b)	→prolog
yasm	dyn.ah62d4rv4ge81w2pxry	dyn — свой UTI (1b)	→asm
yml	public.yaml	системный лист — объявить (1a)	→yaml
yml.mysql	nil	нет типа	→yaml
yrl	dyn.ah62d4rv4ge81w6xq	dyn — свой UTI (1b)	→erlang
yy	public.yacc-source	системный лист — объявить (1a)	→json
yyp	dyn.ah62d4rv4ge81w8pu	dyn — свой UTI (1b)	→json
zcml	dyn.ah62d4rv4ge81y25rru	dyn — свой UTI (1b)	→xml
zig	dyn.ah62d4rv4ge81y4ph	dyn — свой UTI (1b)	→zig
zig.zon	nil	нет типа	→zig
zon	dyn.ah62d4rv4ge81y55s	dyn — свой UTI (1b)	→zig
zs	dyn.ah62d4rv4ge81y62	dyn — свой UTI (1b)	→zenscript
zsh	public.zsh-script	системный лист — объявить (1a)	→shellscript
zsh-theme	dyn.ah62d4rv4ge81y65kfz4gu3prqy	dyn — свой UTI (1b)	→shellscript
```

*(строка `.nim` помечена «*» — см. оговорку выше, фактически это свой прежний артефакт QuickLookers, не системный тип; для планирования трактовать как 1b.)*

Всего расширений в датасете: 813 (после уникализации по расширению). Строк «нет типа» (`nil`) в выводе — те, что содержат точку внутри самого расширения (`adoc.txt`, `cmakelists.txt`, `ssh/config` и т. п.) — `UTType(filenameExtension:)` не резолвит составные/многоточечные строки; это ожидаемо и не входит ни в категорию 1a, ни в 1b (отдельный случай для будущего рассмотрения, не в скоупе этой задачи).

## Итоговый список 1a — объявить системный UTI

```
.ada → public.ada-source  (ada)
.adb → public.ada-source  (ada)
.ads → public.ada-source  (ada)
.app → com.apple.application-file  (erlang)
.applescript → com.apple.applescript.text  (applescript)
.as → com.apple.applesingle-archive  (actionscript-3)
.bash → public.bash-script  (shellscript)
.c → public.c-source  (c)
.c++ → public.c-plus-plus-source  (cpp)
.cc → public.c-plus-plus-source  (cpp)
.cfg → public.toml  (ini)
.cl → public.opencl-source  (common-lisp)
.command → com.apple.terminal.shell-script  (shellscript)
.cp → public.c-plus-plus-source  (cpp)
.cpp → public.c-plus-plus-source  (cpp)
.css → public.css  (css)
.csv → public.comma-separated-values-text  (csv)
.cxx → public.c-plus-plus-source  (cpp)
.dds → com.microsoft.dds  (cobol)
.diff → public.patch-file  (diff)
.exs → com.apple.logic.exs  (elixir)
.f → public.fortran-source  (fortran-fixed-form)
.f77 → public.fortran-77-source  (fortran-fixed-form)
.f90 → public.fortran-90-source  (fortran-free-form)
.f95 → public.fortran-95-source  (fortran-free-form)
.for → public.fortran-source  (fortran-fixed-form)
.frag → org.khronos.glsl.fragment-shader  (glsl)
.fs → org.khronos.glsl.fragment-shader  (fsharp)
.fsh → org.khronos.glsl.fragment-shader  (glsl)
.geojson → public.geojson  (json)
.geom → org.khronos.glsl.geometry-shader  (glsl)
.glsl → org.khronos.glsl-source  (glsl)
.gltf → org.khronos.gltf  (json)
.gp → com.arobas-music.guitarpro.document  (gnuplot)
.gs → org.khronos.glsl.geometry-shader  (genie)
.gsh → org.khronos.glsl.geometry-shader  (glsl)
.h → public.c-header  (c)
.h++ → public.c-plus-plus-header  (cpp)
.hh → public.c-plus-plus-header  (cpp)
.hlsl → com.microsoft.hlsl  (hlsl)
.hpp → public.c-plus-plus-header  (cpp)
.htm → public.html  (html)
.html → public.html  (html)
.hxx → public.c-plus-plus-header  (cpp)
.i → public.c-source.preprocessed  (asm)
.ini → com.microsoft.ini  (ini)
.inl → public.c-plus-plus-inline-header  (cpp)
.ipp → public.c-plus-plus-header  (cpp)
.jav → com.sun.java-source  (java)
.java → com.sun.java-source  (java)
.javascript → com.netscape.javascript-source  (javascript)
.js → com.netscape.javascript-source  (javascript)
.json → public.json  (json)
.ksh → public.ksh-script  (shellscript)
.l → public.lex-source  (common-lisp)
.livemd → com.fluxmarkdown.livemd  (markdown)
.log → com.apple.log  (log)
.m → public.objective-c-source  (objective-c)
.mak → public.make-source  (make)
.make → public.make-source  (make)
.markdown → net.daringfireball.markdown  (markdown)
.md → net.daringfireball.markdown  (markdown)
.mdown → com.fluxmarkdown.mdown  (markdown)
.mdwn → com.fluxmarkdown.mdwn  (markdown)
.mdx → com.fluxmarkdown.mdx  (mdx)
.mjs → com.netscape.javascript-source  (javascript)
.mk → public.make-source  (make)
.mkd → com.fluxmarkdown.mkd  (markdown)
.mkdn → com.fluxmarkdown.mkdn  (markdown)
.mkdown → com.fluxmarkdown.mkdown  (markdown)
.mm → public.objective-c-plus-plus-source  (objective-cpp)
.mmd → com.fluxmarkdown.mmd  (mermaid)
.mod → org.videolan.mod  (xml)
.mts → public.avchd-mpeg-2-transport-stream  (typescript)
.nasm → public.nasm-assembly-source  (asm)
.nim → com.quicklookers.nim-source  (nim)   ← артефакт (см. оговорку), фактически 1b
.pas → public.pascal-source  (pascal)
.patch → public.patch-file  (diff)
.pf → com.apple.colorsync-profile  (fortran-free-form)
.php → public.php-script  (php)
.php3 → public.php-script  (php)
.php4 → public.php-script  (php)
.pl → public.perl-script  (perl)
.pls → public.pls-playlist  (plsql)
.pm → public.perl-script  (perl)
.pot → com.microsoft.powerpoint.pot  (po)
.potx → org.openxmlformats.presentationml.template  (po)
.pp → cx.c3.pp-archive  (pascal)
.proto → public.protobuf-source  (proto)
.py → public.python-script  (python)
.r → com.apple.rez-source  (r)
.rb → public.ruby-script  (ruby)
.rbw → public.ruby-script  (ruby)
.rss → public.rss  (xml)
.s → public.assembly-source  (asm)
.scpt → com.apple.applescript.script  (applescript)
.sdc → org.openoffice.spreadsheet  (tcl)
.sh → public.shell-script  (shellscript)
.sql → org.iso.sql  (sql)
.storyboard → com.apple.dt.interfacebuilder.document.storyboard  (xml)
.swift → public.swift-source  (swift)
.toml → public.toml  (toml)
.tool → com.apple.terminal.shell-script  (shellscript)
.ts → public.mpeg-2-transport-stream  (typescript)
.tsv → public.tab-separated-values-text  (tsv)
.tsx → com.microsoft.typescript  (tsx)
.url → com.microsoft.internet-shortcut  (ini)
.vert → org.khronos.glsl.vertex-shader  (glsl)
.vs → org.khronos.glsl.vertex-shader  (glsl)
.vsh → org.khronos.glsl.vertex-shader  (glsl)
.xht → public.xhtml  (html)
.xhtml → public.xhtml  (html)
.xib → com.apple.interfacebuilder.document.cocoa  (xml)
.xlf → org.oasis-open.xliff  (xml)
.xliff → org.oasis-open.xliff  (xml)
.xml → public.xml  (xml)
.xmp → com.seriflabs.xmp  (xml)
.yaml → public.yaml  (yaml)
.yml → public.yaml  (yaml)
.yy → public.yacc-source  (json)
.zsh → public.zsh-script  (shellscript)
```

## Итоговый список 1b — свои UTI (dyn)

```
4dform, 4dproject, 6pl, 6pm, _coffee, _emacs, _js, a51, abap, abbrev_defs, acl, ad, adml, admx, ado, adoc, adp, al, ant, apacheconf, apex, apl, apla, aplc, aplf, apli, apln, aplo, ara, asc, asciidoc, asd, asdf, asm, astro, auk, aux, avsc, aw, awk, axaml, axml, bal, bat, bats, bb, bbx, bdy, be, beancount, bib, bibtex, bicep, bicepparam, blade, bones, boot, bsl, builder, builds, cairo, cake, cask, cats, cbl, cblcpy, cblle, cblsrce, cbx, ccp, ccproj, ccxml, cdc, cdf, cgi, cginc, cjs, cjsx, cl2, clang-format, clar, clixml, clj, cljc, cljs, cljscm, cljx, cls, cmake, cmd, cnf, cob, cobcopy, cobol, code-snippets, code-workspace, coffee, conf, copybook, coq, cppm, cproject, cpy, cql, cr, cs, cscfg, csdef, cshtml, csl, csproj, csx, ct, ctp, cts, cue, cyp, cypher, d, dart, ddl, def, depproj, desktop, dfm, di, dita, ditamap, ditaval, dm, dme, dml, do, dockerfile, dof, doh, dotsettings, dpk, dpp, dpr, dtx, dump, dyalog, dyapp, edge, el, elc, eld, eliom, eliomi, elm, emacs, env, envvars, erb, erl, es, es6, escript, ex, eye, f03, f08, f18, fastcgi_params, fcgi, fd, feature, filters, fish, fmx, fnc, fnl, fp, fpp, frg, fshader, fsi, fsproj, fst, fsti, fsx, ftl, fx, fxh, fxml, gawk, gd, gdshader, gemspec, geo, gjs, glade, gleam, glslf, glslv, gml, gmx, gnu, gnuplot, gnus, go, god, gql, graphcool, graphql, graphqls, groovy, grt, grxml, gshader, gst, gtpl, gts, gvy, gyp, gypi, hack, haml, handlebars, har, hbs, hcl, hhi, hic, hjson, hlean, hlsli, hrl, hs, hs-boot, hsc, hsig, hta, htaccess, htgroups, htpasswd, http, hx, hxml, hxsl, hy, hzp, ice, iced, idc, ihlp, imba, imba2, iml, inc, ino, ins, ivy, ixx, j2, jade, jake, jbuilder, jelly, jinja, jinja2, jison, jl, jsb, jscad, jsfl, jsh, jslib, jsm, json5, jsonc, jsonl, jsonnet, jspre, jsproj, jss, jssm, jssm_state, jsx, kml, kojo, kql, kt, ktm, kts, kusto, launch, lbx, lean, lektorproject, less, lfm, libsonnet, linq, liquid, lisp, lks, lmi, lpr, lsp, ltx, lua, luau, ma, makefile, marko, mata, matah, mathematica, matlab, mawk, mcmeta, mdpolicy, mediawiki, mermaid, mipage, mips, mir, mjml, mkfile, mkii, mkiv, mkvi, ml, ml4, mli, mll, mly, mojo, move, mspec, mt, mxml, mysql, nas, natvis, nawk, nb, nbp, ncl, ndproj, nf, nginx, nginxconf, ngx, nim (артефакт — трактовать как dyn), nimble, nimrod, nims, nix, njs, nomad, nproj, nqp, nse, nu, nuspec, ny, odd, os, osm, p, p6, p6l, p6m, p8, pac, pascal, pck, pco, pcss, pd_lua, pdv, perl, ph, php5, phps, phpt, pkb, pkgproj, pkh, pks, pl6, plb, plot, plsql, plt, pluginspec, plx, pm6, po, podsl, podspec, polar, postcss, pq, pqm, prawn, prc, prefs, prisma, pro, proj, prolog, properties, props, ps1, ps1xml, psc1, psd1, psgi, psm1, pt, pug, purs, py3, pyde, pyi, pyp, pyt, pyw, qbs, qhelp, ql, qll, qml, query, rabl, rake, raku, rakumod, razor, rbi, rbuild, rbx, rbxs, rchit, rd, rdf, re, reek, reg, regex, regexp, res, rest, resx, rhtml, riscv, rkt, rktd, rktl, rmiss, rockspec, ronn, rpy, rq, rs, rst, rsx, ru, ruby, rviz, sarif, sas, sass, sbt, sc, scala, scb, scbl, scd, scgi_params, sch, scm, scrbl, scss, scxml, sdbl, sel, service, sexp, sfproj, sh-session, shader, shproj, sjs, sld, sls, sol, soy, spacemacs, sparql, spc, spec, spim, spl, splunk, sps, sq, sqlcblle, src, srdf, ss, ssh_config, sshd_config, ssjs, st, sthlp, story, sty, styl, stylus, sublime-build, sublime-color-scheme, sublime-commands, sublime-completions, sublime-keymap, sublime-macro, sublime-menu, sublime-mousemap, sublime-project, sublime-settings, sublime-snippet, sublime-syntax, sublime-theme, sublime-workspace, sublime_metrics, sublime_session, sv, svelte, svh, sw, syntax, t, tab, tac, talon, targets, tasl, tcc, tcl, templ, tesc, tese, tex, tf, tfstate, tfvars, thor, tm, tml, tmux, toc, topojson, tpb, tpp, tps, trg, trigger, tsp, ttl, turtle, twig, txx, typ, udf, ui, urdf, uwsgi_params, ux, v, vala, vapi, vb, vba, vbhtml, vbproj, vcxproj, veo, vh, vhd, vhdl, vhf, vhi, vho, vhost, vhs, vht, vhw, vim, vimrc, viper, viw, vmb, vrx, vshader, vsixmanifest, vssettings, vstemplate, vue, vv, vw, vxml, vy, wast, wat, watchr, webapp, webmanifest, wgsl, wiki, wikitext, wixproj, wks, wl, wls, wlt, wlua, workbook, workflow, wsdl, wsf, wsgi, wxi, wxl, wxs, x3d, xacro, xaml, xdc, xmi, xproj, xpy, xrl, xsd, xsjs, xsjslib, xsl, xslt, xspec, xul, yap, yasm, yrl, yyp, zcml, zig, zon, zs, zsh-theme
```

## Категория «public.data — невод (2)» (побочно замечено)

Две записи попали не в 1a/1b, а под невод `public.data`: `json-tmlanguage`, `yaml-tmlanguage` — оба ведут на служебные вспомогательные расширения (используются во внутренних грамматиках, не как основной формат кода), в датасет и текущую задачу не входят по существу, но зафиксированы для полноты картины.
