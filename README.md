# crawline

[![Travis](https://img.shields.io/travis/u6k/crawline.svg)](https://travis-ci.org/u6k/crawline) [![license](https://img.shields.io/github/license/u6k/crawline.svg)](LICENSE) [![GitHub release](https://img.shields.io/github/release/u6k/crawline.svg)](https://github.com/u6k/crawline/releases) [![Website](https://img.shields.io/website-up-down-green-red/https/redmine.u6k.me%2Fprojects%2Fcrawline.svg?label=u6k.Redmine)](https://redmine.u6k.me/projects/crawline) [![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

> クローラー向けのクラス・ライブラリ

クローラー向けにクローリング・エンジン、キャッシュ管理、パーサーのベース・クラスを提供します。パーサーを実装してクローリング・エンジンに登録することで、簡単にクローリングを行うことができます。

__Table of Contents__

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
    - [S3をセットアップする](#s3%E3%82%92%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97%E3%81%99%E3%82%8B)
    - [パーサーを実装する](#%E3%83%91%E3%83%BC%E3%82%B5%E3%83%BC%E3%82%92%E5%AE%9F%E8%A3%85%E3%81%99%E3%82%8B)
    - [クローリングを開始する](#%E3%82%AF%E3%83%AD%E3%83%BC%E3%83%AA%E3%83%B3%E3%82%B0%E3%82%92%E9%96%8B%E5%A7%8B%E3%81%99%E3%82%8B)
- [Other](#other)
- [Maintainer](#maintainer)
- [Contribute](#contribute)
- [License](#license)

## Background

クローラーのライブラリやフレームワークはいくつもありますが、これらは私がほしい要件を満たしませんでした。私は次の要件を満たしたく、そのために当ライブラリを実装しました。

- Webページのダウンロード可否を複雑なルールで制御したい
    - 前回のダウンロードが1日前以上で、ページ内のデータが1年以内の場合、など
- ダウンロードしたデータはS3ストレージに格納したい
    - 既存のクローラーは、ほとんどの場合、ローカル・ストレージに格納する機能を持っています
- Webページを解析して次にダウンロードするURLを構築したい
    - 単純にWebページのaタグを辿るのではなく

クローリングをどのように実行するのか(CLIアプリケーション、Webアプリケーション、など…)は、当ライブラリを実装する側の責務とします。

## Install

```
gem 'crawline', :git => 'git://github.com/u6k/crawline.git'
```

## Usage

### S3をセットアップする

ダウンロードしたWebデータは、S3互換ストレージに格納します。あらかじめ、Amazon S3のバケットを作成して、アクセス・キーなど必要情報を入手してください。

ローカル環境のみで実行したい場合、S3互換ストレージとして [minio](https://www.minio.io/) などを利用することができます。実際、当プロジェクトもテスト実行の場合はminioを利用しています。詳細は、 [docker-compose.yml](docker-compose.yml) を参照してください。

### パーサーを実装する

テスト用に簡単なパーサーを実装してあります。 [spec/test_parser.rb](spec/test_parser.rb) を参照してください。

### クローリングを開始する

クローリングは`Crawline::Engine`が行いますので、これを初期化します。

`Crawline::Engine`は、`Crawline::Downloader`、`Crawline::ResourceRepository`、そしてパーサー配列を必要とします。

```
# User-Agentを渡して、Crawline::Downloaderを初期化する。
downloader = Crawline::Downloader.new("test/0.0.0")

# S3認証情報を渡して、Crawline::ResourceRepositoryを初期化する。
repo = Crawline::ResourceRepository.new(access_key, secret_key, region, bucket, endpoint, force_path_style)

# 正規表現とパーサーの配列を構築する。
# URLが正規表現にマッチしたパーサーを使用して、ダウンロードしたデータをパースする。
parsers = {
  /https:\/\/blog.example.com\/index\.html/ => BlogListTestParser,
  /https:\/\/blog.example.com\/page[0-9]+\.html/ => BlogListTestParser,
  /https:\/\/blog.example.com\/pages\/.*\.html/ => BlogPageTestParser,
}

# Crawline::Engineを初期化する。
engine = Crawline::Engine.new(downloader, repo, parsers)
```

クローリングは、`Crawline::Engine#crawl`メソッドにURLを渡すことで行います。

```
engine.crawl("https://blog.example.com/index.html")
```

クロールは、実際は「Webからデータをダウンロード」しています。パースはこの後に`Crawline::Engine#parse`メソッドにURLを渡すことで行います。

```
result = engine.parse("https://blog.example.com/index.html")
```

パースは、実際は「各パーサーの`parse`メソッドを呼び出し、`context`に設定された値を返す」を行います。

テスト用に簡単なクロール & パースを実装してあります。 [spec/crawline_spec.rb](spec/crawline_spec.rb) を参照してください。

## Other

最新の情報は、 [Wiki - crawline - u6k.Redmine](https://redmine.u6k.me/projects/crawline/wiki) を参照してください。 [Wiki - crawline - u6k.Redmine](https://redmine.u6k.me/projects/crawline/wiki) は常に編集しており、バージョン・アップのときにREADMEに反映します。

- [要求、要件](https://redmine.u6k.me/projects/crawline/wiki/%E8%A6%81%E6%B1%82%E3%80%81%E8%A6%81%E4%BB%B6)
- [ビルド手順](https://redmine.u6k.me/projects/crawline/wiki/%E3%83%93%E3%83%AB%E3%83%89%E6%89%8B%E9%A0%86)
- [リリース手順](https://redmine.u6k.me/projects/crawline/wiki/%E3%83%AA%E3%83%AA%E3%83%BC%E3%82%B9%E6%89%8B%E9%A0%86)
- [コンポーネント構造](https://redmine.u6k.me/projects/crawline/wiki/%E3%82%B3%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%8D%E3%83%B3%E3%83%88%E6%A7%8B%E9%80%A0)
- [クローリングで配慮すべきこと](https://redmine.u6k.me/projects/crawline/wiki/%E3%82%B9%E3%82%AF%E3%83%AC%E3%82%A4%E3%83%94%E3%83%B3%E3%82%B0%E5%87%A6%E7%90%86%E3%83%95%E3%83%AD%E3%83%BC)
- [スクレイピング処理フロー](https://redmine.u6k.me/projects/crawline/wiki/%E3%82%B9%E3%82%AF%E3%83%AC%E3%82%A4%E3%83%94%E3%83%B3%E3%82%B0%E5%87%A6%E7%90%86%E3%83%95%E3%83%AD%E3%83%BC)
- [参考リンク](https://redmine.u6k.me/projects/crawline/wiki/%E5%8F%82%E8%80%83%E3%83%AA%E3%83%B3%E3%82%AF)

## Maintainer

- u6k
    - [Twitter](https://twitter.com/u6k_yu1)
    - [GitHub](https://github.com/u6k)
    - [Blog](https://blog.u6k.me/)

## Contribute

当プロジェクトに興味を持っていただき、ありがとうございます。 [新しいチケットを起票](https://redmine.u6k.me/projects/crawline/issues/) していただくか、プルリクエストをサブミットしていただけると幸いです。

当プロジェクトは、 [Contributor Covenant](https://www.contributor-covenant.org/version/1/4/code-of-conduct) に準拠します。

## License

[MIT License](LICENSE)
