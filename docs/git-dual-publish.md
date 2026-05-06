# نشر المشروع إلى GitHub وGitLab بأمان

هذا المشروع يحتوي على سكربتين جاهزين:

- Linux/macOS: `scripts/push_dual_remotes.sh`
- Windows PowerShell: `scripts/push_dual_remotes.ps1`

لا تحفظ أي توكن أو كلمة مرور داخل السكربتات. استخدم SSH agent أو Git Credential Manager أو Secrets في CI/CD.

## 1. الإعداد

عدّل المتغيرات أعلى السكربت المناسب لنظامك:

```bash
PROJECT_DIR="/path/to/project"
GITHUB_REMOTE_URL="git@github.com:USER/REPO.git"
GITLAB_REMOTE_URL="git@gitlab.com:USER/REPO.git"
MAIN_BRANCH="main"
AUTH_METHOD="SSH"
REPOSITORIES_ALREADY_CREATED="نعم"
```

أو شغّل السكربت بمتغيرات بيئية بدون تعديل الملف:

```bash
PROJECT_DIR="." \
GITHUB_REMOTE_URL="git@github.com:USER/REPO.git" \
GITLAB_REMOTE_URL="git@gitlab.com:USER/REPO.git" \
MAIN_BRANCH="main" \
AUTH_METHOD="SSH" \
REPOSITORIES_ALREADY_CREATED="نعم" \
./scripts/push_dual_remotes.sh --dry-run
```

في Windows PowerShell:

```powershell
$env:PROJECT_DIR="."
$env:GITHUB_REMOTE_URL="git@github.com:USER/REPO.git"
$env:GITLAB_REMOTE_URL="git@gitlab.com:USER/REPO.git"
$env:MAIN_BRANCH="main"
$env:AUTH_METHOD="SSH"
$env:REPOSITORIES_ALREADY_CREATED="نعم"
.\scripts\push_dual_remotes.ps1 -DryRun
```

## 2. المصادقة عبر SSH

1. أنشئ مفتاح SSH إن لم يكن موجوداً:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

2. شغّل ssh-agent وأضف المفتاح:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

في Windows PowerShell:

```powershell
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519
```

3. أضف محتوى المفتاح العام إلى GitHub وGitLab:

```bash
cat ~/.ssh/id_ed25519.pub
```

4. اختبر الاتصال:

```bash
ssh -T git@github.com
ssh -T git@gitlab.com
```

## 3. المصادقة عبر Personal Access Token

1. أنشئ Token من المنصة، بصلاحية محدودة:
   - GitHub: صلاحية كتابة للمستودع أو `contents: read/write`.
   - GitLab: `write_repository`.
2. استخدم روابط HTTPS عادية في السكربت، مثل:

```bash
GITHUB_REMOTE_URL="https://github.com/USER/REPO.git"
GITLAB_REMOTE_URL="https://gitlab.com/USER/REPO.git"
AUTH_METHOD="PAT"
```

3. لا تضع التوكن داخل الرابط في السكربت. استخدم Git Credential Manager:

```bash
git credential-manager configure
```

4. عند أول `git push` أدخل اسم المستخدم والتوكن عند الطلب، وسيحفظهما Credential Manager في مخزن آمن.

يمكن أيضاً استخدام `GIT_ASKPASS` في البيئات الآلية، بشرط أن يأتي التوكن من متغير بيئي آمن لا من ملف داخل المستودع.

## 4. التشغيل

رابط GitHub مضبوط حالياً على:

```bash
https://github.com/Ahmedbakr78/BigData-.git
```

قبل التشغيل الفعلي عدّل رابط GitLab في السكربت أو مرره كمتغير بيئي.
إذا لم تضف رابط GitLab بعد، سيعمل السكربت على GitHub فقط ويعرض تحذيراً.

نفّذ فحصاً أولاً:

```bash
./scripts/push_dual_remotes.sh --dry-run
```

ثم نفّذ الرفع الفعلي:

```bash
./scripts/push_dual_remotes.sh
```

في Windows:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\push_dual_remotes.ps1 -DryRun
.\scripts\push_dual_remotes.ps1
```

## 5. CI/CD من GitHub إلى GitLab

تمت إضافة الملف `.github/workflows/sync.yml`. غيّر الفرع من `main` إلى `master` إذا لزم.

أضف Secrets في GitHub:

- `GITLAB_PUSH_URL`
  - SSH: `git@gitlab.com:GROUP/PROJECT.git`
  - PAT: `https://oauth2:TOKEN@gitlab.com/GROUP/PROJECT.git`
- `GITLAB_SSH_PRIVATE_KEY` اختياري عند استخدام SSH.

عند استخدام SSH في CI، أضف المفتاح العام كمفتاح Deploy Key في GitLab مع صلاحية write.

## 6. تحذيرات خاصة بهذا المشروع

- يوجد مجلد `.git` فارغ حالياً؛ السكربت سيهيئه عبر `git init` عند التشغيل الفعلي.
- تم تجاهل `.env` و`secrets/` وملفات السجلات وقواعد البيانات والأرشيفات والنسخ الاحتياطية الكبيرة.
- تم تجاهل ملفات CSV المولدة الكبيرة مثل `data/input/full_input.csv` و`data_hub/csv/` و`final_database/csv/` وملفات flights الكبيرة في `hadoop-tasks/task2/`.
- الملف `backup_data.tar.gz` كبير جداً، وGitHub قد يرفض ملفات أكبر من 100MB. إن كانت البيانات الكبيرة مطلوبة في المستودع فاستخدم Git LFS بدلاً من Git العادي.
- لا تستخدم `credential.helper store` لأنه يحفظ الأسرار كنص صريح. استخدم Git Credential Manager أو ssh-agent.
