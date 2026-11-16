# SilverStripe 4 — referenca (ss-version-aware)

Pročitaj prije pisanja koda u projektu na CMS 4. Sadrži samo ono što se razlikuje od 3/5/6 ili što modeli često pomiješaju — nije potpuni API priručnik.
Ciljna verzija je CMS 4.13 (posljednja 4.x). Provjereno na granama `4` (framework = 4.13.x, cms, recipe-core, recipe-cms, installer, siteconfig) i `1` (admin, assets, asset-admin, versioned).
Dvije najčešće greške u 4: kod iz CMS 5/6 (`SilverStripe\Model\...`, `Core\Validation`, `protected` extension hookovi, `orderBy()`) i navike iz CMS 3 (globalna imena klasa, `Page_Controller`, `Session::get()`). Za prelazak na 5 koristi `migrations/4-to-5.md` (`M45-NNN`).

## Osnovno

- PHP 7.4–8.1 (CMS 4.11+); baza MySQL ≥ 5.6 (PostgreSQL/SQL Server/SQLite preko zasebnih modula). Izvor: https://docs.silverstripe.org/en/4/getting_started/server_requirements/#php , https://docs.silverstripe.org/en/4/getting_started/server_requirements/#database
- Moduli: `silverstripe/framework` 4, `cms` 4, `admin` 1, `assets` 1, `versioned` 1, `asset-admin` 1, `siteconfig` 4, `errorpage` 1, `reports` 4, `graphql` 3 ili 4, `campaign-admin` 1, `versioned-admin` 1, `session-manager` 1 (`recipe-cms` 4); `recipe-core` 4 = framework + assets + config + mimevalidator. Izvor: https://github.com/silverstripe/recipe-cms/blob/4/composer.json , https://github.com/silverstripe/recipe-core/blob/4/composer.json
- Struktura: `app/src`, `app/_config/*.yml`, `app/templates` (do 4.2 `mysite/` i `code/`), `themes/<tema>/templates`, moduli u `vendor/`, `.env` u korijenu. Web root je `public/` (od 4.1; stariji projekti mogu imati web root u korijenu — obavezan tek u 5, M45-088). Izvor: https://docs.silverstripe.org/en/4/getting_started/directory_structure/#custom-code-structure , https://docs.silverstripe.org/en/4/getting_started/server_requirements/#public-webroot
- Izloženi resursi: direktorij je `resources/` po defaultu, a installer 4 ga postavlja na `_resources` (`extra.resources-dir` u `composer.json`) — nikad ga ne hardkodiraj (M45-082). Folder iz `app/` (npr. `app/css`) mora biti u `extra.expose` (pa `composer vendor-expose`) da bi `Requirements::css('app/css/x.css')` radio uz `public/` web root. Izvor: https://github.com/silverstripe/silverstripe-installer/blob/4/composer.json , https://docs.silverstripe.org/en/4/developer_guides/templates/requirements/#configuring-your-project-exposed-folders , https://docs.silverstripe.org/en/4/developer_guides/templates/requirements/#exposing-assets-webroot
- `Page` i `PageController` su u globalnom namespaceu (`app/src/Page.php`, `app/src/PageController.php`); kontroler za `App\PageType\HomePage` je `App\PageType\HomePageController` (isti namespace) ili config `controller_name`. `HomePage_Controller` još radi, ali je zastario. Izvor: https://github.com/silverstripe/recipe-cms/blob/4/app/src/PageController.php , https://github.com/silverstripe/silverstripe-cms/blob/4/code/Model/SiteTree.php
- CLI: `vendor/bin/sake dev/build "flush=1"`, `vendor/bin/sake dev/tasks/<segment>`; u browseru `/dev/build?flush=1`. Izvor: https://docs.silverstripe.org/en/4/developer_guides/cli/#usage

## Namespace-ovi i klase

Stanje u CMS 4.13. Sve core klase imaju namespace; u YAML-u se piše puni FQCN (`::class` tamo ne postoji). Ime koje nije ovdje provjeri u `vendor/silverstripe/*`.

| Klasa | Namespace (FQCN) | Izvor |
|---|---|---|
| `DataObject` | `SilverStripe\ORM\DataObject` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/DataObject.php |
| `DataList` | `SilverStripe\ORM\DataList` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/DataList.php |
| `DataExtension` (standard za DataObject u 4) | `SilverStripe\ORM\DataExtension` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/DataExtension.php |
| `Extension` | `SilverStripe\Core\Extension` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Extension.php |
| `ViewableData` | `SilverStripe\View\ViewableData` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/View/ViewableData.php |
| `ArrayData` | `SilverStripe\View\ArrayData` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/View/ArrayData.php |
| `ArrayList` | `SilverStripe\ORM\ArrayList` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/ArrayList.php |
| `PaginatedList` | `SilverStripe\ORM\PaginatedList` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/PaginatedList.php |
| `SS_List` | `SilverStripe\ORM\SS_List` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/SS_List.php |
| `ArrayLib` | `SilverStripe\ORM\ArrayLib` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/ArrayLib.php |
| `ValidationResult` | `SilverStripe\ORM\ValidationResult` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/ValidationResult.php |
| `ValidationException` | `SilverStripe\ORM\ValidationException` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/ValidationException.php |
| `DBDatetime` (u `$db`: `'Datetime'`) | `SilverStripe\ORM\FieldType\DBDatetime` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/FieldType/DBDatetime.php |
| `SQLSelect` | `SilverStripe\ORM\Queries\SQLSelect` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/Queries/SQLSelect.php |
| `RequiredFields` | `SilverStripe\Forms\RequiredFields` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Forms/RequiredFields.php |
| `CompositeValidator` (4.7+) | `SilverStripe\Forms\CompositeValidator` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Forms/CompositeValidator.php |
| `GridFieldConfig_RecordEditor` | `SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Forms/GridField/GridFieldConfig_RecordEditor.php |
| `TinyMCEConfig` (TinyMCE 4) | `SilverStripe\Forms\HTMLEditor\TinyMCEConfig` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Forms/HTMLEditor/TinyMCEConfig.php |
| `BuildTask` | `SilverStripe\Dev\BuildTask` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Dev/BuildTask.php |
| `Controller` | `SilverStripe\Control\Controller` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Control/Controller.php |
| `HTTPRequest` (u 3: `SS_HTTPRequest`) | `SilverStripe\Control\HTTPRequest` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Control/HTTPRequest.php |
| `HTTPResponse` | `SilverStripe\Control\HTTPResponse` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Control/HTTPResponse.php |
| `Email` (SwiftMailer) | `SilverStripe\Control\Email\Email` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Control/Email/Email.php |
| `HTTPCacheControlMiddleware` | `SilverStripe\Control\Middleware\HTTPCacheControlMiddleware` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Control/Middleware/HTTPCacheControlMiddleware.php |
| `Environment` (`getEnv()`) | `SilverStripe\Core\Environment` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Environment.php |
| `Injector` | `SilverStripe\Core\Injector\Injector` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Injector/Injector.php |
| `Requirements` | `SilverStripe\View\Requirements` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/View/Requirements.php |
| `Security` | `SilverStripe\Security\Security` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Security/Security.php |
| `PasswordValidator` | `SilverStripe\Security\PasswordValidator` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Security/PasswordValidator.php |
| `HTTPOutputHandler` | `SilverStripe\Logging\HTTPOutputHandler` | https://github.com/silverstripe/silverstripe-framework/blob/4/src/Logging/HTTPOutputHandler.php |
| `SiteTree` | `SilverStripe\CMS\Model\SiteTree` | https://github.com/silverstripe/silverstripe-cms/blob/4/code/Model/SiteTree.php |
| `SiteTreeExtension` | `SilverStripe\CMS\Model\SiteTreeExtension` | https://github.com/silverstripe/silverstripe-cms/blob/4/code/Model/SiteTreeExtension.php |
| `ContentController` | `SilverStripe\CMS\Controllers\ContentController` | https://github.com/silverstripe/silverstripe-cms/blob/4/code/Controllers/ContentController.php |
| `SilverStripeNavigator` (u 5 u admin, M45-004) | `SilverStripe\CMS\Controllers\SilverStripeNavigator` | https://github.com/silverstripe/silverstripe-cms/blob/4/code/Controllers/SilverStripeNavigator.php |
| `ModelAdmin` | `SilverStripe\Admin\ModelAdmin` | https://github.com/silverstripe/silverstripe-admin/blob/1/code/ModelAdmin.php |
| `LeftAndMainExtension` | `SilverStripe\Admin\LeftAndMainExtension` | https://github.com/silverstripe/silverstripe-admin/blob/1/code/LeftAndMainExtension.php |
| `UploadField` | `SilverStripe\AssetAdmin\Forms\UploadField` | https://github.com/silverstripe/silverstripe-asset-admin/blob/1/code/Forms/UploadField.php |
| `Image` | `SilverStripe\Assets\Image` | https://github.com/silverstripe/silverstripe-assets/blob/1/src/Image.php |
| `Versioned` | `SilverStripe\Versioned\Versioned` | https://github.com/silverstripe/silverstripe-versioned/blob/1/src/Versioned.php |
| `SiteConfig` | `SilverStripe\SiteConfig\SiteConfig` | https://github.com/silverstripe/silverstripe-siteconfig/blob/4/code/SiteConfig.php |

## Potpisi i obrasci

**DataObject** — `validate()` je `public` bez povratnog tipa; `getCMSFields()` preko `beforeUpdateCMSFields()`; uvijek `$table_name`.

```php
namespace App\Model;

use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\TextareaField;
use SilverStripe\ORM\DataObject;

class Project extends DataObject
{
    private static $table_name = 'App_Project';   // bez ovoga: tabela App_Model_Project + upozorenje na dev/build
    private static $db = ['Title' => 'Varchar(255)', 'Status' => "Enum('Draft,Active','Draft')", 'Deadline' => 'Datetime', 'Summary' => 'Text'];
    private static $has_one = ['Owner' => Client::class];
    private static $has_many = ['Tasks' => Task::class];      // Task: has_one 'Project' => Project::class
    private static $many_many = ['Tags' => Tag::class];

    public function getCMSFields()
    {
        $this->beforeUpdateCMSFields(function (FieldList $fields) {
            // isto ime kao scaffoldano polje => zamjenjuje ga
            $fields->addFieldToTab('Root.Main', TextareaField::create('Summary', 'Sažetak'));
        });
        return parent::getCMSFields();
    }

    public function validate()   // vraća SilverStripe\ORM\ValidationResult
    {
        $result = parent::validate();
        if (!$this->Title) {
            $result->addFieldError('Title', 'Naslov je obavezan');
        }
        return $result;
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/DataObject.php , https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/DataObjectSchema.php , https://docs.silverstripe.org/en/4/developer_guides/model/validation/
Napomena: `protected function validate()` je fatalno (roditelj je `public`). U `Page` podklasi `onBeforeDelete()`/`onAfterDelete()` moraju biti `public` (SiteTree), `onBeforeWrite()`/`onAfterWrite()` mogu ostati `protected`. Nema `scaffold_cms_fields_settings` (5.3) ni `class_description` (5.4). Izvor: https://github.com/silverstripe/silverstripe-cms/blob/4/code/Model/SiteTree.php

**DataExtension** — svi hookovi moraju biti `public`: `extend()` ih poziva izvana (`$instance->$method(...)`), pa je `protected` hook (5.0+ stil) greška "Call to protected method".

```php
namespace App\Extension;

use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\TextField;
use SilverStripe\ORM\DataExtension;
use SilverStripe\ORM\ValidationResult;

class MemberProfileExtension extends DataExtension
{
    private static $db = ['Position' => 'Varchar(100)'];

    public function updateCMSFields(FieldList $fields)
    {
        $fields->addFieldToTab('Root.Main', TextField::create('Position', 'Pozicija'));
    }

    public function validate(ValidationResult $validationResult)   // u 6: updateValidate()
    {
        if (strlen((string) $this->getOwner()->Position) > 100) {
            $validationResult->addFieldError('Position', 'Predugo');
        }
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Extensible.php , https://docs.silverstripe.org/en/4/developer_guides/extending/extensions/ , https://docs.silverstripe.org/en/5/changelogs/5.0.0/#extension-changes
Napomena: `LeftAndMain`/`ModelAdmin` extension hook je `public function init()`; kontroler extension: `onBeforeInit()`/`onAfterInit()`. Izvor: https://github.com/silverstripe/silverstripe-admin/blob/1/code/LeftAndMain.php

**PageController / Controller** — `init()` je `protected` i mora zvati `parent::init()`; akcije u `$allowed_actions`, form akcije (`doSubmit`) ne.

```php
namespace App\PageType;

use PageController;
use SilverStripe\Forms\EmailField;
use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\Form;
use SilverStripe\Forms\FormAction;
use SilverStripe\Forms\RequiredFields;
use SilverStripe\ORM\ValidationResult;

class ContactPageController extends PageController   // stranica: App\PageType\ContactPage
{
    private static $allowed_actions = ['ContactForm'];

    protected function init()
    {
        parent::init();
    }

    public function ContactForm()
    {
        $fields = FieldList::create(EmailField::create('Email', 'E-mail'));
        $actions = FieldList::create(FormAction::create('doSubmit', 'Pošalji'));
        return Form::create($this, 'ContactForm', $fields, $actions, RequiredFields::create('Email'));
    }

    public function doSubmit($data, Form $form)
    {
        $form->sessionMessage('Hvala!', ValidationResult::TYPE_GOOD);
        return $this->redirectBack();
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/Control/Controller.php , https://docs.silverstripe.org/en/4/developer_guides/forms/introduction/
Napomena: `redirect()`/`redirectBack()` u 4 nemaju povratni tip (tipovi od 5.0, M45-065); sesija je `$this->getRequest()->getSession()`, ne statički `Session::get()`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#session

**GridField** u `getCMSFields()`:

```php
// SilverStripe\Forms\GridField\GridField, SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor
$fields->addFieldToTab('Root.Tasks', GridField::create('Tasks', 'Zadaci', $this->Tasks(), GridFieldConfig_RecordEditor::create(20)));
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/Forms/GridField/GridField.php , https://docs.silverstripe.org/en/4/developer_guides/forms/field_types/gridfield/

**CMS validator** — od 4.7 `getCMSCompositeValidator()` (povratni tip je obavezan jer ga roditelj deklariše); `getCMSValidator()` i dalje radi.

```php
public function getCMSCompositeValidator(): CompositeValidator   // SilverStripe\Forms\CompositeValidator
{
    $validator = parent::getCMSCompositeValidator();
    $validator->addValidator(RequiredFields::create(['Title']));   // SilverStripe\Forms\RequiredFields
    return $validator;
}
```

Izvor: https://docs.silverstripe.org/en/4/developer_guides/forms/validation/#validation-in-the-cms , https://docs.silverstripe.org/en/4/changelogs/4.7.0/

**BuildTask** — `run($request)` bez tipa parametra (`HTTPRequest` tip je fatalan); URL iz `$segment`.

```php
namespace App\Tasks;

use SilverStripe\Dev\BuildTask;
use SilverStripe\ORM\DB;

class CleanupTask extends BuildTask
{
    private static $segment = 'cleanup';   // bez ovoga: dev/tasks/App-Tasks-CleanupTask
    protected $title = 'Čišćenje';
    protected $description = 'Briše stare zapise';
    protected $enabled = true;             // false = isključen (config is_enabled tek od 5.1)

    public function run($request)   // $request je SilverStripe\Control\HTTPRequest
    {
        if ($request->getVar('dry-run')) {
            DB::alteration_message('Dry run');
            return;
        }
        // ...
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/Dev/BuildTask.php , https://github.com/silverstripe/silverstripe-framework/blob/4/src/Dev/TaskRunner.php , https://docs.silverstripe.org/en/4/changelogs/4.0.0/#buildtask-segment

**ModelAdmin** — `getGridFieldConfig()` postoji od 4.6; ranije (i u 3) preko `getEditForm()`.

```php
namespace App\Admin;

use App\Model\Project;
use SilverStripe\Admin\ModelAdmin;
use SilverStripe\Forms\GridField\GridFieldConfig;

class ProjectAdmin extends ModelAdmin
{
    private static $managed_models = [Project::class];
    private static $url_segment = 'projects';
    private static $menu_title = 'Projekti';
    private static $menu_icon_class = 'font-icon-database';

    protected function getGridFieldConfig(): GridFieldConfig
    {
        $config = parent::getGridFieldConfig();
        return $config;
    }
}
```

Izvor: https://docs.silverstripe.org/en/4/developer_guides/customising_the_admin_interface/modeladmin/#overriding-the-methods-on-modeladmin , https://github.com/silverstripe/silverstripe-admin/blob/1/code/ModelAdmin.php

## Config/YAML

```yaml
---
Name: app-extensions
---
SilverStripe\Security\Member:
  extensions:
    - App\Extension\MemberProfileExtension
---
Name: app-passwords
After: '#corepasswords'
---
SilverStripe\Core\Injector\Injector:
  SilverStripe\Security\PasswordValidator:
    properties:
      MinLength: 12
---
Name: app-emailconfig
After:
  - '#emailconfig'
---
SilverStripe\Core\Injector\Injector:
  Swift_Transport:
    class: Swift_SmtpTransport
    properties:
      Host: smtp.example.com
    calls:
      Username: [ setUsername, ['`APP_SMTP_USERNAME`'] ]   # env/konstanta u backtickovima, samo u Injector configu
      Password: [ setPassword, ['`APP_SMTP_PASSWORD`'] ]
```

Izvor: https://docs.silverstripe.org/en/4/developer_guides/extending/extensions/ , https://github.com/silverstripe/silverstripe-framework/blob/4/_config/passwords.yml , https://docs.silverstripe.org/en/4/developer_guides/email/#configuration
Napomena: mail u 4 je SwiftMailer (`Swift_Transport`); `MAILER_DSN` i `symfony/mailer` su tek u 5 (M45-007, M45-070, M45-071). Bez configa 4 koristi zastarjeli `Swift_MailTransport` (PHP `mail()`).

- `Only`/`Except` pravila: `classexists`, `moduleexists`, `environment` (`dev`/`test`/`live`), `envvarset`, `constantdefined`, `envorconstant`, `extensionloaded`. Izvor: https://docs.silverstripe.org/en/4/developer_guides/configuration/configuration/#exclusionary-rules
- Česta `After`/`Before` imena: framework `#coreconfig`, `#corepasswords`, `#coreroutes`, `#rootroutes`, `#emailconfig`, `#logging`, `#corecache`; cms `#cmsextensions`, `#modelascontrollerroutes`; admin `#adminroutes`; assets `#assetsflysystem`. Izvor: https://github.com/silverstripe/silverstripe-framework/tree/4/_config , https://github.com/silverstripe/silverstripe-cms/tree/4/_config , https://github.com/silverstripe/silverstripe-admin/tree/1/_config , https://github.com/silverstripe/silverstripe-assets/tree/1/_config
- Teme: `SilverStripe\View\SSViewer: themes: ['$public', 'simple', '$default']` (ne `theme:`, M45-041). Izvor: https://github.com/silverstripe/silverstripe-installer/blob/4/app/_config/theme.yml
- Config u PHP-u: `Config::modify()->set()` / `->merge()`, `$this->config()->get()`; `Config::inst()->update()` u 4 ne radi (`Config::inst()` je nepromjenjiv nakon boota) — koristi `Config::modify()`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Config/Config.php , https://docs.silverstripe.org/en/4/changelogs/4.0.0/#config
- `.env`: `SS_DATABASE_CLASS` (`MySQLDatabase` ili `MySQLPDODatabase` — PDO uklonjen u 5, M45-012), `SS_DATABASE_SERVER`, `SS_DATABASE_USERNAME`, `SS_DATABASE_PASSWORD`, `SS_DATABASE_NAME`, `SS_ENVIRONMENT_TYPE`, `SS_DEFAULT_ADMIN_USERNAME`/`_PASSWORD`, `SS_BASE_URL`, `SS_ALLOWED_HOSTS`, `SS_TRUSTED_PROXY_IPS`, `SS_SEND_ALL_EMAILS_TO`, `SS_ERROR_LOG`. U PHP-u: `Environment::getEnv('X')`. Izvor: https://docs.silverstripe.org/en/4/getting_started/environment_management/#core-environment-variables

## Templati

- Engine je `SSViewer` (framework), templati `*.ss`; klasa s namespaceom traži `templates/App/PageType/Layout/HomePage.ss`, globalna `templates/Layout/Page.ss`. Izvor: https://docs.silverstripe.org/en/4/developer_guides/templates/template_inheritance/#template-types-and-locations
- U petlji: `$IsFirst`/`$IsLast` (od 4.7; `$First`/`$Last` rade, ali su zastarjeli od 4.12 i uklonjeni u 5, M45-078), `$Middle`, `$FirstLast`, `$Even`/`$Odd`/`$EvenOdd`, `$Pos`, `$FromEnd`, `$TotalItems`, `$Modulus(n)`, `$MultipleOf(n)`. Izvor: https://docs.silverstripe.org/en/4/developer_guides/templates/syntax/#position-indicators , https://github.com/silverstripe/silverstripe-framework/blob/4/src/View/SSViewer_BasicIteratorSupport.php
- Opseg: `$Up` = prethodni, `$Top` = osnovni; dodatni selektori u izrazu petlje (`<% loop $Children.Sort('Title').First %>`) implicitno dodaju nivo, pa treba `$Up.Up...` — u 5 je to jedan nivo (M45-079). Izvor: https://docs.silverstripe.org/en/4/developer_guides/templates/syntax/#up
- Include ne vidi roditeljski opseg — proslijedi argumente: `<% include MemberDetails Top=$Top, Name=$Name %>`; `<% include X %>` traži `Includes/X.ss`, pa `X.ss`. Izvor: https://docs.silverstripe.org/en/4/developer_guides/templates/syntax/#includes , https://docs.silverstripe.org/en/4/changelogs/4.0.0/#template-locations
- Argumenti metoda u templatu su uvijek stringovi (`$Foo(true)` → `'true'`, `$Foo(1)` → `'1'`); tip zadržavaju tek od 5 (M45-081). Izvor: https://docs.silverstripe.org/en/5/changelogs/5.0.0/#primitive-values-can-be-passed-into-method-calls
- Resursi: `$resourceURL('app/images/x.png')`, `$themedResourceURL('images/x.png')`, `<% require css("app/css/x.css") %>`, `<% require themedCSS("layout") %>`; `$ThemeDir` je zastario od 4.0.1 (uklonjen u 5, M45-080). Izvor: https://docs.silverstripe.org/en/4/developer_guides/templates/requirements/ , https://github.com/silverstripe/silverstripe-framework/blob/4/src/View/ViewableData.php
- Uslovi: `||` i `&&`; poređenja `==`, `!=`, `<`, `>`, `<=`, `>=`; `<% if not $X %>`. Nema `or`/`and` (parser odbija, iako docs-4 tvrdi suprotno). `<% control %>` (SS3) je parse error — koristi `<% loop %>`/`<% with %>`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/View/SSTemplateParser.peg
- i18n: `<%t Namespace.KEY "Zdravo {name}" name=$Name %>`; stari `<% _t(...) %>` ne koristi (uklonjen u 6, M56-095). Izvor: https://docs.silverstripe.org/en/4/developer_guides/i18n/#usage-in-template-files
- Varijable se escapaju prema `casting`/`default_cast` (`Text`); HTML iz metode treba `private static $casting = ['X' => 'HTMLText']`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#template-casting

## Česte greške

Format: **Ne** (iz 3, 5 ili 6) → **Da** (CMS 4.13). ID vodi na stavku u `migrations/4-to-5.md` ili `migrations/5-to-6.md` sa izvorom.

Kod iz CMS 5/6 (u 4 ne postoji ili je fatalno) — smjer je obrnut: "Ne" je kolona **Novo** mape, "Da" kolona **Staro** (CMS 4):

- Ne: `protected function updateCMSFields()` / bilo koji `protected` extension hook (5.0+) → Da: `public function ...` — `Extensible::extend()` u 4 poziva hook izvana. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Extensible.php
- Ne: `SilverStripe\Model\ModelData` / `Model\ArrayData` / `Model\List\*` → Da: `SilverStripe\View\ViewableData` / `View\ArrayData` / `SilverStripe\ORM\ArrayList` itd. (M56-011, M56-010, M56-002 do M56-007).
- Ne: `SilverStripe\Core\Validation\ValidationResult` / `Forms\Validation\RequiredFieldsValidator` → Da: `SilverStripe\ORM\ValidationResult` / `SilverStripe\Forms\RequiredFields` (M56-009, M56-015).
- Ne: `BuildTask::execute(InputInterface, PolyOutput): int`, `sake db:build`, `sake tasks:x` → Da: `public function run($request)`, `sake dev/build "flush=1"`, `sake dev/tasks/x` (M56-071, M56-109).
- Ne: hook `updateValidate` / `onAfterPopulateDefaults` / `onRequireDefaultRecords` / LeftAndMain `onInit` → Da: `validate` / `populateDefaults` / `requireDefaultRecords` / `init` (M56-059, M56-060, M56-061, M56-064).
- Ne: `DataList::orderBy('RAND()')` (5.0+) → Da: `sort('RAND()')` (M45-069); `limit(null)` za "bez limita" radi i u 4, `limit(0)` je zastario od 4.3 (M45-068). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/Queries/SQLSelect.php
- Ne: `MAILER_DSN`, `Symfony\Component\Mailer\*`, `try { $email->send(); } catch (TransportExceptionInterface ...)` → Da: `Swift_Transport` u Injectoru; `$email->send()` vraća `bool` (M45-007, M45-067, M45-070).
- Ne: `SilverStripe\Security\SudoMode\SudoModeService`, `SilverStripe\Admin\Navigator\SilverStripeNavigator` → Da: `silverstripe/security-extensions` modul, `SilverStripe\CMS\Controllers\SilverStripeNavigator` (M45-002, M45-004, M45-085).
- Ne: `class_description`, `scaffold_cms_fields_settings`, `AdminController`, `SingleRecordAdmin` → Da: ne postoje u 4; opis tipa stranice je `SiteTree` config `private static $description` (M56-082); `getCMSEditLink()` → `CMSEditLink()` (M56-051).
- Ne: `$IsFirst` u CMS < 4.7 → Da: `$First`; od 4.7 `$IsFirst` (preporučeno, radi i u 5/6).

Navike iz CMS 3 (u 4 uklonjeno ili zastarjelo):

- Ne: globalna imena (`DataObject`, `Controller`, `SS_HTTPRequest`, `Injector:` kao YAML ključ) → Da: FQCN + `use` (`SilverStripe\ORM\DataObject`, `SilverStripe\Control\HTTPRequest`, `SilverStripe\Core\Injector\Injector:`); relacije `'Author' => Member::class`, ne `'Member'`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#literal-class-names
- Ne: `Page_Controller` / `HomePage_Controller` → Da: `PageController` / `HomePageController` u namespaceu stranice (`_Controller` radi uz deprecation, u 5 uklonjeno, M45-092). Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#controllers-renamed
- Ne: `public function init()` u kontroleru (3 stil) → Da: `protected function init()` kao `Controller::init()` (`public` je dozvoljen, ali nije konvencija). Izvor: https://github.com/silverstripe/recipe-cms/blob/4/app/src/PageController.php
- Ne: `extends Object`, `Object::add_extension('File', 'X')`, `$this->class` → Da: traitovi `Injectable`/`Configurable`/`Extensible`, `File::add_extension(X::class)`, `static::class`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#object-replace
- Ne: tabela = ime klase, hardkodirano `"Project"` u SQL-u → Da: `$table_name` + `DataObject::getSchema()->tableName(Project::class)`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#literal-table-names
- Ne: `'SS_Datetime'` u `$db` → Da: `'Datetime'` (u 4 nema `SS_Datetime` aliasa); `SS_Datetime::now()` → `DBDatetime::now()`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#dbfield-rename , https://github.com/silverstripe/silverstripe-framework/blob/4/_config/model.yml
- Ne: `$result->error('poruka')`, `$result->valid()` → Da: `$result->addError()` / `addFieldError()`, `isValid()`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/ORM/ValidationResult.php
- Ne: `Session::get('x')` / `Session::set()` → Da: `$request->getSession()->get('x')`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#session
- Ne: `_ss_environment.php` s `define()`, `mysite/_config.php` s `$project`/`$database`/`ConfigureFromEnv.php` → Da: `.env` + YAML `SilverStripe\Core\Manifest\ModuleManifest: project: app`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#config-php , https://docs.silverstripe.org/en/4/getting_started/environment_management/
- Ne: `Config::inst()->update('Class', 'x', $v)` → Da: `Config::modify()->set(Class::class, 'x', $v)` / `merge()`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#config
- Ne: `public static $db` / `public static $allowed_actions` → Da: `private static` (javne statičke config vrijednosti se ignorišu). Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#private-static
- Ne: `SQLQuery` → Da: `SQLSelect` / `SQLUpdate` / `SQLInsert` / `SQLDelete`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#sqlquery
- Ne: `Requirements::css('mysite/css/x.css')`, hardkodirano `'framework/css/x.css'` → Da: `Requirements::css('app/css/x.css')` ili `'vendor/modul:putanja'` (izloženi resursi, npr. `'silverstripe/admin:client/dist/js/bundle.js'`; razmak oko `:` je dozvoljen). Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#module-paths , https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Manifest/ModuleResourceLoader.php
- Ne: `$Image.SetWidth(200)` / `$Image.CroppedImage(100,100)` → Da: `$Image.ScaleWidth(200)` / `$Image.Fill(100,100)`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#image-handling
- Ne: `<% control $X %>` → Da: `<% loop $X %>` / `<% with $X %>` (parse error u 4). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/View/SSTemplateParser.peg
- Ne: `Versioned("Stage","Live")` u `extensions` → Da: u YAML-u `SilverStripe\Versioned\Versioned`, u PHP-u `Versioned::class`; objava: `publishRecursive()` uz `private static $owns`. Izvor: https://docs.silverstripe.org/en/4/developer_guides/model/versioning/#applying-the-versioned-extension-to-your-dataobject

Zastarjelo u 4.x (radi, ali piši odmah kompatibilno sa 5 gdje 4 to dozvoljava; M45 u smjeru naprijed):

- Ne: `Member::currentUser()` / `currentUserID()` → Da: `Security::getCurrentUser()` (postoji od 4.0; M45-023).
- Ne: `$First`/`$Last`, `$ThemeDir` → Da: `$IsFirst`/`$IsLast` (4.7+), `$themedResourceURL()` (M45-078, M45-080).
- Ne: `$this->config()->update()` / `Config::modify()->update()` → Da: `merge()` / `set()` (M45-029); `$this->stat('x')` → `$this->config()->get('x')` (M45-028).
- Ne: `Convert::raw2json()` / `json2array()` → Da: `json_encode()` / `json_decode()` (M45-030).
- Ne: `Versioned::doPublish()` / `publish($from, $to)` → Da: `publishRecursive()` / `copyVersionToStage($from, $to)` (M45-053).
- Ne: `DataExtension` / `SiteTreeExtension` za novi kod koji ide na 6 → Da: u 4 ostaje `DataExtension` (standard); `Extension` radi i za `$db`, ali hookovi i dalje `public` (M56-036). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/4/src/Core/Config/Middleware/ExtensionMiddleware.php
