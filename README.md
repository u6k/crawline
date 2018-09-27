# crawline

[![Travis](https://img.shields.io/travis/u6k/crawline.svg)](https://travis-ci.org/u6k/crawline)
[![license](https://img.shields.io/github/license/u6k/crawline.svg)](https://github.com/u6k/crawline/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/u6k/crawline.svg)](https://github.com/u6k/crawline/releases)
[![Website](https://img.shields.io/website-up-down-green-red/https/redmine.u6k.me%2Fprojects%2Fcrawline.svg?label=u6k.Redmine)](https://redmine.u6k.me/projects/crawline)
[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

> Webクローリングとスクレイピングを行う基盤アプリケーション

Webページをデータソースとするアプリケーションに向けて、当基盤がWebクローリングとスクレイピングを行い、その結果のデータを提供します。当基盤にルールを登録しておいて、URLをパラメータとしてクローリングを要求すると、ルールに沿ってクローリングとスクレイピングを行います。ダウンロードしたデータの管理、キャッシュ管理などは当基盤が行い、個別のアプリケーションはデータモデルの構築に専念することができます。

__Table of Contents__

<!-- TOC depthFrom:2 -->

- [Security](#security)
- [Background](#background)
- [Install](#install)
- [Usage](#usage)
  - [前提](#前提)
  - [アプリケーションを起動する](#アプリケーションを起動する)
  - [スクレイピングのルールを定義する](#スクレイピングのルールを定義する)
  - [URLを起点にクロール、スクレイピングを行う](#urlを起点にクロールスクレイピングを行う)
- [API](#api)
- [Maintainer](#maintainer)
- [Contribute](#contribute)
- [License](#license)

<!-- /TOC -->

## Security

個人用のアプリケーションであり、複数人数が使用することは想定していません。外部からはジョブ・スケジューラーでジョブを実行するだけです。

そのため、認証機能は実装しません。nginx-proxyの機能でBASIC認証を実装しても良いですし、Let's Encryptでサーバー証明書を設定しても良いですが、それは外部アプリケーションの役割とします。

## Background

いくつかの似たようなスクレイピング・アプリケーションを作成してきました。新しいサイトのスクレイピング要件はこれからも出続けるでしょうし、その度に新しいアプリケーションを作るのは、時間とマシン・リソースの無駄と考えます。

そのため、クローリングとスクレイピングの基盤を構築して、複数のサイトに対するスクレイピングを統合したいと考えます。ページに対する解析方法、検証方法、リンク解析方法などを、コードで制御して、気軽に追加・変更できるようにしたいです。ページのキャッシュ制御、旧バージョンの管理なども任せたいです。

解析後のデータのモデル構築などは、個々のアプリケーションがやるべきだと思っていますので、ここでは実装しません。

## Install

__TODO:__ 基盤コードとルール・コードの管理を分けたいです。そのため、[gemによる提供を考えます](https://redmine.u6k.me/issues/6560)

## Usage

### 前提

crawlineは、次のソフトウェアを必要とします。

- Docker

```
$ docker version
Client:
 Version:           18.06.0-ce
 API version:       1.38
 Go version:        go1.10.3
 Git commit:        0ffa825
 Built:             Wed Jul 18 19:09:33 2018
 OS/Arch:           linux/amd64
 Experimental:      false

Server:
 Engine:
  Version:          18.06.0-ce
  API version:      1.38 (minimum version 1.12)
  Go version:       go1.10.3
  Git commit:       0ffa825
  Built:            Wed Jul 18 19:07:38 2018
  OS/Arch:          linux/amd64
  Experimental:     false
```

- docker-compose

```
$ docker-compose version
docker-compose version 1.21.0, build 5920eb0
docker-py version: 3.2.1
CPython version: 3.6.5
OpenSSL version: OpenSSL 1.0.1t  3 May 2016
```

### アプリケーションを起動する

ビルドして、起動します。

```
$ docker-compose build
$ docker-compose up -d
```

Webブラウザで http://localhost:3000/ にアクセスすると、アプリケーションを利用できます。

### スクレイピングのルールを定義する

__TODO:__ 目的、具体的な手順、例を示す

ページに対する解析、検証、リンク抽出方法は、クラスで定義します。XPathで定義とも考えましたが、それだと複雑なページが解析できない気がします。

ダウンロードしたページの保存、キャッシュ制御は基盤が自動的に行います。RFC的なキャッシュ制御の他、「以前のダウンロードから1か月はキャッシュを使う」などの優先独自ルールを設定可能とします。

クローリング時間間隔、異なるドメインへの平行ダウンロードなどは、基盤が制御します。

### URLを起点にクロール、スクレイピングを行う

__TODO:__ 目的、具体的な手順、例を示す

外部からクロールして欲しいURLを指定すると、ルールに従って解析して、リンクを辿れるだけ辿ります。

## API

__TODO:__ APIドキュメントへのリンクを示す

- /okcomputer/all.json
  - ヘルスチェックを返します

## Maintainer

- u6k
  - [Twitter](https://twitter.com/u6k_yu1)
  - [GitHub](https://github.com/u6k)
  - [Blog](https://blog.u6k.me/)

## Contribute

当プロジェクトに興味を持っていただき、ありがとうございます。[新しいチケットを起票](https://redmine.u6k.me/projects/crawline/issues/new)していただくか、プルリクエストをサブミットしていただけると幸いです。

当プロジェクトは、[Contributor Covenant](https://www.contributor-covenant.org/version/1/4/code-of-conduct)に準拠します。

## License

[MIT License](https://github.com/u6k/crawline/blob/master/LICENSE)
