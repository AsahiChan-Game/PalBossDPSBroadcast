[h1]DPSを調べないで[/h1]
[b]Palworld 1.0のシングルプレイ向け軽量ボスダメージメーター。[/b]

ボスを攻撃すると自動で計測を開始します。討伐、捕獲、またはタイムアウト時に結果がゲーム内チャットへ表示されます。

[h2]主な機能[/h2]
[list]
[*]チームダメージ、戦闘時間、DPS、プレイヤー順位、ダメージ割合
[*]プレイヤーと各パルのダメージを個別に記録
[*]パルのユーザー設定ニックネームを優先表示
[*]月亮領主などの複数部位ボスを1つの戦闘として集計
[*]Palworldが対応する17言語へ自動切り替え
[*]任意のリアルタイムレポート、詳細表彰、パル内訳、コメント
[/list]

[h2]導入方法[/h2]
[olist]
[*]このModをサブスクライブします。
[*][url=https://steamcommunity.com/workshop/filedetails/?id=3625223587]UE4SS Experimental (Palworld)[/url]もサブスクライブして有効化します。
[*]PalworldのMod管理で両方を有効化します。
[*]シングルプレイのワールドでボスを攻撃します。
[/olist]

[h2]パルごとのダメージ[/h2]
v1.2.0では、プレイヤーキャラクターと各パルのダメージ、割合、DPSが初期設定で表示されます。[code]config.EnablePalDamageBreakdown = true[/code]で切り替え、短い結果にする場合は[code]false[/code]にしてください。ボス戦の闘技場には対応しますが、PvPアリーナには対応しません。

[h2]対応範囲[/h2]
[list]
[*][b]正式対応：[/b]シングルプレイ
[*][b]試験対応：[/b]ホストモード（ホストのみに表示）
[*][b]非対応：[/b]リモートクライアントからサーバー全体のダメージを集計
[/list]

専用サーバー版は[url=https://github.com/AsahiChan-Game/PalBossDPSBroadcast]GitHub[/url]をご利用ください。

[i]非公式コミュニティModです。Pocketpair、Steam、UE4SSとは無関係です。翻訳修正を歓迎します。[/i]
