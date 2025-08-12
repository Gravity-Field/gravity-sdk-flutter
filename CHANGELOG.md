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
