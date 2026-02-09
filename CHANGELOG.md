## 0.14.0
* Добавлен флаг isFetchContentOnTrack в setOptions для управления загрузкой контента в trackViewNoShow/triggerEventNoShow
* Добавлен метод triggerTrackingUrl
* Исправлен метод sendContentEngagement
* Оптимизация взаимодействия с бэкендом

## 0.13.1
* Правки по батчингу

## 0.13.0
* Обновлён api url
* Скорректирована конвертация цвета из web-формата

## 0.12.2
* Правки по батчингу

## 0.12.1
* Добавлен виджет GravityInlineListWidget
* Класс Container переименован в FrameContainer
* Скорректированы настройки width, margin и padding у InlineContent 
* Скорректированы настройки padding у GravityButton
* Обновлена версия gradle у example

## 0.12.0
* Добавлена поддержка headless api

## 0.11.1
* Добавлена возможность указать свой индикатор загрузки у GravityInlineWidget

## 0.11.0
* Добавлена возможность добавления фона элементам через атрибут backgroundImage
* Добавлен новый тип элемента - webview
* Добавлена возможность вертикального выравнивания в FullScreenContent
* Исправлена отправка VisibleImpression у GravityInlineWidget

## 0.10.2
* Добавлена возможность управления уровнями логирования

## 0.10.1
* Обновлены версии пакетов
* Настроено отображение товаров во всплывающих окнах
* Добавлено отображение товаров в формате сетки
* Настроена корректная отправка engagement-запросов

## 0.10.0
* Оптимизация взаимодействия с бэкендом
* Удалены неиспользуемые зависимости

## 0.9.13
* Добавлена поддержка отображения контента в GravityInlineWidget в зависимости от placeholderId.

## 0.9.12
* Добавлены скругления углов для GravityImageWidget.
* Фикс выравнивания GravityText.

## 0.9.11
* Обновлён example.

## 0.9.10
* Фикс скругления углов у bottom sheet.

## 0.9.9
* Соответствие nullable и required полей API.

## 0.9.8
* Закрытие bottom sheet при нажатии на кнопку. Отключатеся через closeOnClick = false в классе OnClick.
* В поле attributes объекта PageContenxt подмешиваются app_version, sdk_version, app_platform
* ContentSettings перемещены в data.options
* InlineWidget не рендериться в случае ошибки получения данных.

## 0.9.6

* Фикс кеширования и отправки сессии.
* Скругление углов у кнопки.

## 0.9.5

* Удалена зависимость от пакета notification_permissions. 
* Добавлена возможность задать статус разрешения уведомлений извне.

## 0.9.4

* Исправлены значения enum product_action
* Поле Item в объекте Slot теперь просто Map<String, dynamic>

## 0.9.3

* В объекте device предаются tracking и permission.

## 0.9.2

* Удалены последствия патча.

## 0.9.1

* Исправлена отправка ctx в event.
* Поле events в объекте Slot теперь nullable.
* Поля categories и keywords в объекте Item теперь nullable.
* Обработка клика по картинке.
* Отправка isBuildEngagementUrl в Options
* Поле name в Event переименовано в type.

## 0.9.0

* Поля pageNumber и countPage в Products теперь опциональные.
* Добавлена возможность передавать PageContext в GravityInlineWidget
* Добавлены CampaignContent и Campaign в ProductWidgetBuilder

## 0.8.10

* Поправлена ошибка с парсингом CampaignIdsResponse

## 0.8.9

* Отображение sneckbar.

## 0.8.8

* Получение и отображение компаний в ответ на trackView и triggerEvent

## 0.8.7

* Исправлены ошибки в методе event

## 0.8.6

* Исправлены ошибки в методе visit

## 0.8.5

* В качестве id устройства используется UUID
* UserAgent передаётся строкой.

## 0.8.4

* Добавлены поля data, location, lng, utm, attributes в класс PageContext.
* Поля hashedEmail, cuid, cuidType теперь не обязательные.

## 0.8.3

* Обновлён README.md. Исправлена навигация в Оглавлении.

## 0.8.2

* Обновлён README.md. Добавлено описание ProductWidgetBuilder.

## 0.8.1

* Initial release
