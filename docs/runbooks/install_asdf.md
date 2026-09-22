# macOS에서 asdf 설치 및 사용 가이드 (zsh 기준)

## 설치

```bash
# 1. Homebrew로 asdf 설치
brew install asdf

# 2. zsh 설정 파일에 초기화 스크립트 추가
echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ~/.zshrc

# 3. 설정 적용
source ~/.zshrc

# 4. 설치 확인
asdf --version
```

## 기본 사용법

```bash
# 플러그인 추가
asdf plugin add terramate https://github.com/emrahcetiner/asdf-terramate.git
asdf plugin add opentofu https://github.com/virtualroot/asdf-opentofu.git

# 설치 가능한 버전 확인
asdf list all terramate

# 버전 설치
asdf install terramate latest
asdf install opentofu latest

# 버전 설정 (로컬 - 현재 디렉토리)
echo "terramate latest" > .tool-versions
echo "opentofu latest" >> .tool-versions

# 또는 버전 설정 (전역 - 홈 디렉토리)
echo "terramate latest" > ~/.tool-versions
echo "opentofu latest" >> ~/.tool-versions

# 설치된 버전 확인
asdf list terramate

# 현재 사용 중인 버전 확인
asdf current
```