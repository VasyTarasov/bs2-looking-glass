# English and Russian variants — 0.99995-dev

The mod uses the language of the verified installed game. The installer UI can independently switch between English and Russian. [Installation and recovery](INSTALL.md).

All 2,401 skill/item/weapon/armor/state identities match the original English game database by ID. Names come directly from the original `Game.rgss3a` distributed with the game. Original descriptions, game scripts and assets are not included in the mod. The original game's lore and gameplay remain in the player's installation.

English covers mod settings, V/B/M/N groups, weapons, action queues, macros, F7, H effects, HD panels, equipment comparisons, saves, field skills, shortcuts and notifications. English cards default to English and remain English when the old reference-language key is pressed. Russian installations retain their previous RU/EN reference behavior.

The game databases differ in 11 improved weapons' flat MAT or AGI: Warhammer +6..+9, Miranda's Axe +2..+4 and Deep Sea Knight's Anchor +2..+5. English factual data preserve the actual English values, including negative penalties. The mod does not adjust the balance. English ring families also recognize native spacing before `+3`.

English UI source is compiled from reviewed literals in `localization/en.json`. `tools/build_localization.py --check` rejects missing or stale compiled text. Arithmetic and actions use the shared implementation. Obsolete handwritten note tables are superseded by the complete factual catalog; the English catalog removes 221 Russian shelf summaries.

## Русский

В установщике есть отдельный выбор языка установленной игры и переключатель языка самого установщика. Английский вариант требует английскую игру; русская игра автоматически не переводится.

Оригинальный английский `Game.rgss3a` распаковывать не нужно. Установщик хранит проверенный оригинал в `BS2Suite/Game.original.rgss3a`, добавляет загрузчик в копию архива и проверяет результат. При удалении возвращается побайтно исходный архив. Остальные зашифрованные ресурсы неизменны. Нужно примерно 1,1 ГБ дополнительного места для резервной и временной копий.

Названия сверены напрямую с английской базой; отдельно учтены 11 отличий параметров улучшенного оружия. Игровые параметры мод не меняет. Неверный язык, неизвестные изменения активных файлов и конфликтующие записи уже установленного мода отклоняются до установки. Распакованные базовые Data рядом с проверенным архивом сохраняются: движок использует архив.

Проверки подтверждают указанные сценарии, а не полное сюжетное прохождение. Исторический сбой F12 не объявлен исправленным. Это development-сборка.
