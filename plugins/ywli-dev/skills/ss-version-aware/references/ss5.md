# SilverStripe 5 — referenca (ss-version-aware)

Pročitaj prije pisanja koda u projektu na CMS 5. Sadrži samo ono što se razlikuje od 4/6 ili što modeli često pomiješaju — nije potpuni API priručnik.
Ciljna verzija je CMS 5.4 (posljednja 5.x). Provjereno na granama `5` (framework, cms, recipe-core, recipe-cms, installer) i `2.4` (admin, assets, asset-admin, versioned).
Najčešća greška u 5 je kod iz CMS 6 (`SilverStripe\Model\...`, `Core\Validation`, `BuildTask::execute()`) — te klase u 5 ne postoje. Za prelazak sa 4 koristi `migrations/4-to-5.md` (`M45-NNN`), za razliku prema 6 `migrations/5-to-6.md` (`M56-NNN`).

## Osnovno

- PHP 8.1–8.2 za CMS 5.0–5.1, PHP 8.1–8.3 za 5.2+; baza: LTS verzije MySQL/MariaDB. Composer 2. Izvor: https://docs.silverstripe.org/en/5/getting_started/server_requirements/#php-support , https://docs.silverstripe.org/en/5/getting_started/server_requirements/#database
- Moduli: `silverstripe/framework` 5, `cms` 5, `admin` 2, `assets` 2, `versioned` 2, `asset-admin` 2, `siteconfig` 5, `errorpage` 2, `reports` 5, `graphql` 5, `campaign-admin` 2, `session-manager` 2 (svi u `recipe-cms` 5). Izvor: https://github.com/silverstripe/recipe-core/blob/5/composer.json , https://github.com/silverstripe/recipe-cms/blob/5/composer.json
- TinyMCE (6) je dio frameworka (`SilverStripe\Forms\HTMLEditor\TinyMCEConfig`); template engine (`SSViewer`, `SSTemplateParser`) je u `SilverStripe\View`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/5/src/Forms/HTMLEditor/TinyMCEConfig.php
- Struktura: `app/src`, `app/_config/*.yml`, `app/templates` (`*.ss`), `themes/<tema>/templates`, web root `public/` je obavezan (M45-088), izloženi resursi u `public/_resources`, `.env` u korijenu projekta. Zadana tema installera je `simple`. Izvor: https://docs.silverstripe.org/en/5/getting_started/directory_structure/ , https://github.com/silverstripe/silverstripe-installer/blob/5/composer.json
- `Page` i `PageController` su u globalnom namespaceu; kontroler stranice `App\PageType\HomePage` je `App\PageType\HomePageController` (ne `HomePage_Controller`, M45-092) ili config `controller_name`. Izvor: https://github.com/silverstripe/recipe-cms/blob/5/app/src/PageController.php , https://docs.silverstripe.org/en/5/developer_guides/controllers/introduction/#connecting-pages-to-controllers
- CLI: `vendor/bin/sake dev/build flush=1`, `sake dev/tasks/<segment>`; u browseru `/dev/build?flush=1`, `/dev/tasks/<segment>`. Nema `sake db:build`. Izvor: https://docs.silverstripe.org/en/5/developer_guides/cli/#usage

## Namespace-ovi i klase

Stanje u CMS 5.4. Klase označene kao zastarjele rade do kraja 5.x, ali u 6 ih nema. Ime koje nije ovdje provjeri u `vendor/silverstripe/*`.

| Klasa | Namespace (FQCN) | Izvor |
|---|---|---|
| `DataObject` | `SilverStripe\ORM\DataObject` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/DataObject.php |
| `DataList` | `SilverStripe\ORM\DataList` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/DataList.php |
| `Extension` (preporučeno i za DataObject od 5.3) | `SilverStripe\Core\Extension` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Core/Extension.php |
| `DataExtension` (zastarjelo od 5.3) | `SilverStripe\ORM\DataExtension` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/DataExtension.php |
| `ViewableData` (u 6: `ModelData`) | `SilverStripe\View\ViewableData` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/View/ViewableData.php |
| `ArrayData` | `SilverStripe\View\ArrayData` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/View/ArrayData.php |
| `ArrayList` | `SilverStripe\ORM\ArrayList` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/ArrayList.php |
| `PaginatedList` | `SilverStripe\ORM\PaginatedList` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/PaginatedList.php |
| `GroupedList` | `SilverStripe\ORM\GroupedList` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/GroupedList.php |
| `SS_List` | `SilverStripe\ORM\SS_List` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/SS_List.php |
| `Map` | `SilverStripe\ORM\Map` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/Map.php |
| `ArrayLib` | `SilverStripe\ORM\ArrayLib` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/ArrayLib.php |
| `ValidationResult` | `SilverStripe\ORM\ValidationResult` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/ValidationResult.php |
| `ValidationException` | `SilverStripe\ORM\ValidationException` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/ValidationException.php |
| `RequiredFields` | `SilverStripe\Forms\RequiredFields` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Forms/RequiredFields.php |
| `CompositeValidator` | `SilverStripe\Forms\CompositeValidator` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Forms/CompositeValidator.php |
| `Validator` | `SilverStripe\Forms\Validator` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Forms/Validator.php |
| `BuildTask` (nije `PolyCommand`) | `SilverStripe\Dev\BuildTask` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Dev/BuildTask.php |
| `SSViewer` | `SilverStripe\View\SSViewer` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/View/SSViewer.php |
| `TinyMCEConfig` | `SilverStripe\Forms\HTMLEditor\TinyMCEConfig` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Forms/HTMLEditor/TinyMCEConfig.php |
| `HTTPOutputHandler` | `SilverStripe\Logging\HTTPOutputHandler` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Logging/HTTPOutputHandler.php |
| `PasswordValidator` | `SilverStripe\Security\PasswordValidator` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Security/PasswordValidator.php |
| `SudoModeService` (iz security-extensions, M45-002) | `SilverStripe\Security\SudoMode\SudoModeService` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Security/SudoMode/SudoModeService.php |
| `HTMLValue` (puni FQCN, M45-016) | `SilverStripe\View\Parsers\HTMLValue` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/View/Parsers/HTMLValue.php |
| `Email` (nasljeđuje Symfony `Email`) | `SilverStripe\Control\Email\Email` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Control/Email/Email.php |
| `GridFieldConfig_RecordEditor` | `SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor` | https://github.com/silverstripe/silverstripe-framework/blob/5/src/Forms/GridField/GridFieldConfig_RecordEditor.php |
| `SiteTree` | `SilverStripe\CMS\Model\SiteTree` | https://github.com/silverstripe/silverstripe-cms/blob/5/code/Model/SiteTree.php |
| `SiteTreeExtension` (zastarjelo od 5.3) | `SilverStripe\CMS\Model\SiteTreeExtension` | https://github.com/silverstripe/silverstripe-cms/blob/5/code/Model/SiteTreeExtension.php |
| `ContentController` | `SilverStripe\CMS\Controllers\ContentController` | https://github.com/silverstripe/silverstripe-cms/blob/5/code/Controllers/ContentController.php |
| `ModelAdmin` | `SilverStripe\Admin\ModelAdmin` | https://github.com/silverstripe/silverstripe-admin/blob/2.4/code/ModelAdmin.php |
| `LeftAndMainExtension` (zastarjelo od admin 2.3) | `SilverStripe\Admin\LeftAndMainExtension` | https://github.com/silverstripe/silverstripe-admin/blob/2.4/code/LeftAndMainExtension.php |
| `SilverStripeNavigator` (iz CMS u admin, M45-004) | `SilverStripe\Admin\Navigator\SilverStripeNavigator` | https://github.com/silverstripe/silverstripe-admin/blob/2.4/code/Navigator/SilverStripeNavigator.php |
| `UploadField` | `SilverStripe\AssetAdmin\Forms\UploadField` | https://github.com/silverstripe/silverstripe-asset-admin/blob/2.4/code/Forms/UploadField.php |
| `Image` | `SilverStripe\Assets\Image` | https://github.com/silverstripe/silverstripe-assets/blob/2.4/src/Image.php |
| `Versioned` | `SilverStripe\Versioned\Versioned` | https://github.com/silverstripe/silverstripe-versioned/blob/2.4/src/Versioned.php |

## Potpisi i obrasci

**DataObject** — `validate()` u roditelju nema povratni tip (dodavanje `: ValidationResult` je dozvoljeno, ne obavezno); `getCMSFields()` preko `beforeUpdateCMSFields()`.

```php
namespace App\Model;

use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\TextareaField;
use SilverStripe\ORM\DataObject;

class Project extends DataObject
{
    private static $table_name = 'App_Project';
    private static $db = ['Title' => 'Varchar(255)', 'Summary' => 'Text', 'Status' => "Enum('Draft,Active','Draft')"];
    private static $has_one = ['Owner' => Client::class];
    private static $has_many = ['Tasks' => Task::class];      // Task: has_one 'Project' => Project::class
    private static $many_many = ['Tags' => Tag::class];
    private static $class_description = 'Projekat klijenta';   // 5.4+

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

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/DataObject.php , https://docs.silverstripe.org/en/5/developer_guides/model/validation/#model-validation
Napomena: u 5 nema validacije `DBField`-a (predug `Varchar` se tiho skrati, M56-107). `SiteTree::getCMSFields()` gradi polja ručno (bez scaffoldinga, M56-106); ostali DataObjecti scaffoldaju, a `scaffold_cms_fields_settings` postoji od 5.3. Izvor: https://docs.silverstripe.org/en/5/changelogs/5.3.0/#scaffolding-options

**Extension** — od 5.3 nasljeđuj `SilverStripe\Core\Extension` (ne `DataExtension`); hookovi smiju biti `protected`.

```php
namespace App\Extension;

use SilverStripe\Core\Extension;
use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\TextField;
use SilverStripe\ORM\ValidationResult;

class MemberProfileExtension extends Extension
{
    private static $db = ['Position' => 'Varchar(100)'];

    protected function updateCMSFields(FieldList $fields)
    {
        $fields->addFieldToTab('Root.Main', TextField::create('Position', 'Pozicija'));
    }

    protected function validate(ValidationResult $result)   // u 6: updateValidate()
    {
        if (strlen((string) $this->getOwner()->Position) > 100) {
            $result->addFieldError('Position', 'Predugo');
        }
    }

    protected function populateDefaults() {}        // u 6: onAfterPopulateDefaults()
    protected function requireDefaultRecords() {}   // u 6: onRequireDefaultRecords()
}
```

Izvor: https://docs.silverstripe.org/en/5/changelogs/5.0.0/#extension-changes , https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/DataObject.php
Napomena: ako ipak nasljeđuješ `DataExtension`, on već deklariše `public` metode (`validate`, `updateCMSFields`, `onBeforeWrite`, …) pa hookovi moraju ostati `public` i kompatibilni (https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/DataExtension.php). `LeftAndMain`/`ModelAdmin` extension hook je `init()` (u 6: `onInit`); kontroler extension: `onBeforeInit()`/`onAfterInit()`.

**PageController / Controller** — `init()` je `protected` i mora zvati `parent::init()`; akcije u `$allowed_actions`, form akcije ne.

```php
namespace App\PageType;

use PageController;
use SilverStripe\Control\HTTPResponse;
use SilverStripe\Forms\EmailField;
use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\Form;
use SilverStripe\Forms\FormAction;
use SilverStripe\Forms\RequiredFields;
use SilverStripe\ORM\ValidationResult;

class ContactPageController extends PageController
{
    private static $allowed_actions = ['ContactForm'];

    protected function init()
    {
        parent::init();
    }

    public function ContactForm(): Form
    {
        $fields = FieldList::create(EmailField::create('Email', 'E-mail'));
        $actions = FieldList::create(FormAction::create('doSubmit', 'Pošalji'));
        return Form::create($this, 'ContactForm', $fields, $actions, RequiredFields::create('Email'));
    }

    public function doSubmit(array $data, Form $form): HTTPResponse
    {
        $form->sessionMessage('Hvala!', ValidationResult::TYPE_GOOD);
        return $this->redirectBack();
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/5/src/Control/Controller.php , https://docs.silverstripe.org/en/5/developer_guides/forms/introduction/
Napomena: `redirect(string $url, int $code = 302): HTTPResponse` i `redirectBack(): HTTPResponse` imaju tipove od 5.0 (M45-065); `Controller::curr()` u 5 bez kontrolera izdaje `E_USER_WARNING` i vraća `null` — provjeri `Controller::has_curr()` prije (u 6 uklonjeno, M56-046).

**GridField** u `getCMSFields()`:

```php
$fields->addFieldToTab('Root.Tasks', GridField::create('Tasks', 'Zadaci', $this->Tasks(), GridFieldConfig_RecordEditor::create(20)));
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/5/src/Forms/GridField/GridField.php , https://docs.silverstripe.org/en/5/developer_guides/forms/field_types/gridfield/

**CMS validator** — `getCMSValidator()` je zastario od 5.4; koristi:

```php
public function getCMSCompositeValidator(): CompositeValidator   // SilverStripe\Forms\CompositeValidator
{
    $validator = parent::getCMSCompositeValidator();
    $validator->addValidator(RequiredFields::create(['Title']));
    return $validator;
}
```

Izvor: https://docs.silverstripe.org/en/5/developer_guides/forms/validation/ , https://github.com/silverstripe/silverstripe-framework/blob/5/src/ORM/DataObject.php

**BuildTask** — `run($request)` bez tipa parametra (dodavanje `HTTPRequest` tipa je fatalno); URL iz `$segment`.

```php
namespace App\Tasks;

use SilverStripe\Dev\BuildTask;
use SilverStripe\ORM\DB;

class CleanupTask extends BuildTask
{
    private static $segment = 'cleanup';   // /dev/tasks/cleanup, sake dev/tasks/cleanup
    protected $title = 'Čišćenje';
    protected $description = 'Briše stare zapise';

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

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/5/src/Dev/BuildTask.php , https://github.com/silverstripe/silverstripe-framework/blob/5/src/Dev/Tasks/CleanupTestDatabasesTask.php
Napomena: `$segment` i `$description` su označeni zastarjelim u 5.4, ali zamjena (`$commandName`, statički `$description`) postoji tek u 6. Isključivanje taska: config `is_enabled: false` (ne `protected $enabled`, zastarjelo od 5.1).

**ModelAdmin**:

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

Izvor: https://docs.silverstripe.org/en/5/developer_guides/customising_the_admin_interface/modeladmin/ , https://github.com/silverstripe/silverstripe-admin/blob/2.4/code/ModelAdmin.php
Napomena: u 5 nema `AdminController` ni `SingleRecordAdmin`; config je `tree_class` (u 6 `model_class`).

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
Name: app-services
Only:
  envvarset: 'MY_API_KEY'
---
SilverStripe\Core\Injector\Injector:
  App\Service\ApiClient:
    properties:
      ApiKey: '`MY_API_KEY`'   # env/konstanta u backtickovima, samo u Injector configu
```

Izvor: https://docs.silverstripe.org/en/5/developer_guides/extending/extensions/ , https://github.com/silverstripe/silverstripe-framework/blob/5/_config/passwords.yml , https://docs.silverstripe.org/en/5/developer_guides/extending/injector/#using-constants-and-environment-variables

- `Only`/`Except` pravila: `classexists`, `moduleexists`, `environment` (`dev`/`test`/`live`), `envvarset`, `constantdefined`, `envorconstant`, `extensionloaded`. Izvor: https://docs.silverstripe.org/en/5/developer_guides/configuration/configuration/#exclusionary-rules
- Česta `After`/`Before` imena: framework `#coreconfig`, `#corepasswords`, `#coreroutes`, `#rootroutes`, `#logging`, `#mailer`, `#corecache`; cms `#cmsextensions`, `#modelascontrollerroutes`; admin `#adminroutes`; assets `#assetsflysystem` (nema `#view-config`, to je 6). Izvor: https://github.com/silverstripe/silverstripe-framework/tree/5/_config , https://github.com/silverstripe/silverstripe-cms/tree/5/_config , https://github.com/silverstripe/silverstripe-admin/tree/2.4/_config , https://github.com/silverstripe/silverstripe-assets/tree/2.4/_config , https://docs.silverstripe.org/en/5/developer_guides/configuration/configuration/#before-after-rules
- Logging handler za prikaz grešaka: `class: SilverStripe\Logging\HTTPOutputHandler`. Izvor: https://docs.silverstripe.org/en/5/developer_guides/debugging/error_handling/#setting-a-different-configuration-for-dev
- Teme: `SilverStripe\View\SSViewer: themes: ['$public', 'simple', '$default']` (ne `theme:`, M45-041). Izvor: https://github.com/silverstripe/silverstripe-installer/blob/5/app/_config/theme.yml
- `.env`: `SS_DATABASE_CLASS="MySQLDatabase"` (ne `MySQLPDODatabase`, M45-012), `SS_DATABASE_SERVER`, `SS_DATABASE_USERNAME`, `SS_DATABASE_PASSWORD`, `SS_DATABASE_NAME`, `SS_ENVIRONMENT_TYPE`, `SS_DEFAULT_ADMIN_USERNAME`/`_PASSWORD`, `SS_BASE_URL`, `MAILER_DSN` (https://docs.silverstripe.org/en/5/developer_guides/email/ , umjesto SwiftMailer/`APP_SMTP_*`, M45-070, M45-071), `SS_ALLOWED_HOSTS`, `SS_TRUSTED_PROXY_IPS`. `SS_IN_MEMORY_CACHE_FACTORY` i `SS_SESSION_*` su tek u 6. Izvor: https://docs.silverstripe.org/en/5/getting_started/environment_management/#core-environment-variables

## Templati

- Engine je `SSViewer` (framework), templati `*.ss`. Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/syntax/
- U petlji: `$IsFirst`, `$IsLast`, `$Middle`, `$FirstLast`, `$Even`/`$Odd`/`$EvenOdd`, `$Pos`, `$FromEnd`, `$TotalItems`, `$Modulus(n)`, `$MultipleOf(n)` — `$First`/`$Last` su uklonjeni u 5 (M45-078). Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/syntax/#position-indicators
- `<% loop %>`/`<% with %>` uvode tačno jedan nivo opsega: `$Up` = prethodni, `$Top` = osnovni; `<% loop $X.Limit(5) %>` ne dodaje međuopseg, pa CMS 4 `$Up.Up.Title` u takvoj petlji postaje `$Up.Title` (M45-079). Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/syntax/#up
- Include ne vidi roditeljski opseg — proslijedi argumente: `<% include MemberDetails Top=$Top, Name=$Name %>`. Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/syntax/#includes
- Argument-varijabla se evaluira, ali se šalje kao (escapan) string, ne kao objekat ili tip (`$getThing($Var)` → `XML_val('Var', null, true)`); getter s argumentom se zove punim imenom (`$getThing('x')`, ne `$Thing('x')`). Literali zadržavaju tip (`1`, `true`, `null`, M45-081). Prosljeđivanje vrijednosti s tipom i loop nativnih PHP nizova postoje tek u 6. Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/syntax/#variables , https://github.com/silverstripe/silverstripe-framework/blob/5/src/View/SSTemplateParser.peg , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#improvements-to-template-functionality
- `$Me` poziva `forTemplate()`; ako objekat nema `forTemplate()`, greška. Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/syntax/#fortemplate
- i18n: `<%t Namespace.KEY "Zdravo {name}" name=$Name %>` (radi u 5 i 6; stari `<% _t(...) %>` ne koristi, u 6 je uklonjen — M56-095). Izvor: https://docs.silverstripe.org/en/5/developer_guides/i18n/#usage-in-template-files
- Templati form polja koriste `$Value` (u 6: `$FormattedValue`, M56-096). Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#formfield-value
- Resursi: `$themedResourceURL('images/x.png')` / `$resourceURL('app/images/x.png')`, ne `$ThemeDir` (M45-080) ni hardkodirani `resources/` (M45-082). Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/requirements/
- Uslovi: `||` i `&&`; poređenja `==`, `!=`, `<`, `>`, `<=`, `>=`; negacija `<% if not $X %>`. Nema `or`/`and` (parser odbija — parse error, iako docs-5 tvrdi suprotno). Izvor: https://docs.silverstripe.org/en/5/developer_guides/templates/syntax/#conditional-logic , https://github.com/silverstripe/silverstripe-framework/blob/5/src/View/SSTemplateParser.peg

## Česte greške

Format: **Ne** (iz 4 ili 6) → **Da** (CMS 5.4). ID vodi na stavku u `migrations/4-to-5.md` ili `migrations/5-to-6.md` sa izvorom; u grupi "Kod iz CMS 6" M56 stavke idu unazad: "Ne" je kolona **Novo** (CMS 6), "Da" kolona **Staro**.

Kod iz CMS 6 (u 5 ne postoji):

- Ne: `SilverStripe\Model\ModelData` / `Model\ArrayData` → Da: `SilverStripe\View\ViewableData` / `View\ArrayData` (M56-011, M56-010).
- Ne: `SilverStripe\Model\List\ArrayList` / `PaginatedList` / `GroupedList` / `Map` / `SS_List` → Da: `SilverStripe\ORM\*` (M56-002 do M56-007); `Core\ArrayLib` → `ORM\ArrayLib` (M56-001).
- Ne: `SilverStripe\Core\Validation\ValidationResult` / `ValidationException` → Da: `SilverStripe\ORM\ValidationResult` / `ValidationException` (M56-009, M56-008).
- Ne: `SilverStripe\Forms\Validation\RequiredFieldsValidator` → Da: `SilverStripe\Forms\RequiredFields` (M56-015); `Forms\Validation\CompositeValidator`/`Validator` → `Forms\CompositeValidator`/`Validator` (M56-016, M56-014).
- Ne: `BuildTask::execute(InputInterface, PolyOutput): int`, `$commandName`, `PolyOutput` → Da: `public function run($request)`, `private static $segment` (M56-071, M56-078).
- Ne: `sake db:build --flush`, `sake tasks:x` → Da: `sake dev/build flush=1`, `sake dev/tasks/x` (M56-109).
- Ne: hook `updateValidate` → Da: `validate(ValidationResult $result)` (M56-059); `onAfterPopulateDefaults` → `populateDefaults` (M56-060); `onRequireDefaultRecords` → `requireDefaultRecords` (M56-061); `onFlushCache` → `flushCache` (M56-062); `LeftAndMain` ext `onInit` → `init` (M56-064). Novi nazivi se u 5 nikad ne pozivaju.
- Ne: `getCMSEditLink(): ?string` → Da: `CMSEditLink()` (M56-051).
- Ne: `SilverStripe\TinyMCE\TinyMCEConfig`, paket `silverstripe/htmleditor-tinymce` → Da: `SilverStripe\Forms\HTMLEditor\TinyMCEConfig` (M56-029, M56-102).
- Ne: `ErrorOutputHandler` → Da: `SilverStripe\Logging\HTTPOutputHandler` (M56-026); `Security\Validation\*PasswordValidator` → `SilverStripe\Security\PasswordValidator` (M56-017).
- Ne: `TemplateEngine::renderString()`, `SSTemplateEngine` → Da: `SSViewer::fromString($tpl)->process($data)` (M56-040).
- Ne: `protected function onBeforeDelete()` / `onAfterDelete()` u `Page` podklasi (6 stil) → Da: `public` — u CMS 5 su `SiteTree::onBeforeDelete()`/`onAfterDelete()` public, protected je fatalno. Izvor: https://github.com/silverstripe/silverstripe-cms/blob/5/code/Model/SiteTree.php
- Ne: DB tipovi `'Email'`, `'URL'`, `'IP'` → Da: `'Varchar'` (+ validacija u `validate()`); `DBEmail`/`DBUrl`/`DBIp` su novi u 6. Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#dbfield-validation
- Ne: oslanjanje na `PaginatedList::count()` = stavke stranice → Da: u 5 `count()` vraća ukupan broj (M56-108); `obj('Nepostojece')` u 5 vraća prazan `DBField`, ne `null` (M56-076).

Navike iz CMS 4 (uklonjeno u 5):

- Ne: `Member::currentUser()` / `currentUserID()` → Da: `Security::getCurrentUser()` / `Security::getCurrentUser()?->ID` (M45-023); `$member->logIn()` → `Security::setCurrentUser($member)` (M45-024).
- Ne: `$First`/`$Last` → Da: `$IsFirst`/`$IsLast` (M45-078); `$ThemeDir` → `$themedResourceURL()` (M45-080).
- Ne: `Page_Controller` → Da: `PageController` (M45-092).
- Ne: `$this->config()->update()` / `Config::modify()->update()` → Da: `merge()` ili `set()` (M45-029); `$this->stat('x')` → `$this->config()->get('x')` (M45-028).
- Ne: SwiftMailer (`Swift_*`), `if ($email->send())` → Da: `MAILER_DSN` + `try { $email->send(); } catch (TransportExceptionInterface $e)` (M45-007, M45-070, M45-067).
- Ne: `Convert::raw2json()` / `json2array()` → Da: `json_encode()` / `json_decode()` (M45-030).
- Ne: `limit(0)` za "bez limita" → Da: `limit(null)` (M45-068); `sort('RAND()')` → `orderBy('RAND()')` (M45-069).
- Ne: `DB::getConn()` → Da: `DB::get_conn()` (M45-035); `ClassInfo::baseDataClass()` → `DataObject::getSchema()->baseDataClass()` (M45-031); `Injector::hasService()` → `has()` (M45-032).
- Ne: `doValidate()` → Da: `validate()` (M45-036); override `duplicate()` bez `: static` → `duplicate(bool $doWrite = true, ?array $relations = null): static` (M45-059).
- Ne: `getIterator()`/`offsetGet()` bez povratnog tipa u podklasama `ViewableData`/lista → Da: `getIterator(): Traversable` itd. (M45-063).
- Ne: `HTTP::set_cache_age()` → Da: `HTTPCacheControlMiddleware::singleton()->setMaxAge()` (M45-040); `SSViewer::set_theme()` → `set_themes([...])` (M45-041).
- Ne: `Versioned::doPublish()` / `publish($from, $to)` → Da: `publishRecursive()` / `copyVersionToStage($from, $to)` (M45-053); `Versioned('Stage','Live')` → `SilverStripe\Versioned\Versioned` (M45-075).
- Ne: `$query->nextRecord()` → Da: `foreach ($query as $row)` (M45-045); PHPUnit `setUp()` bez `: void` → `protected function setUp(): void` (M45-060).

Zastarjelo u 5.x (radi, ali piši odmah kompatibilno sa 6 gdje 5 to dozvoljava; M56 u smjeru naprijed):

- Ne: `extends DataExtension` / `SiteTreeExtension` / `LeftAndMainExtension` → Da: `extends SilverStripe\Core\Extension` (dostupno u 5; M56-036 do M56-038).
- Ne: `getCMSValidator()` → Da: `getCMSCompositeValidator(): CompositeValidator` (5.4; M56-050).
- Ne: `SiteTree.description` → Da: `class_description` (5.4; M56-082). Izvor: https://docs.silverstripe.org/en/5/changelogs/5.4.0/#class-description
- Ne: `$this->defaultVal` u `DBField` podklasi → Da: `getDefaultValue()` / `setDefaultValue()` (5.4). Izvor: https://docs.silverstripe.org/en/5/changelogs/5.4.0/#deprecated-api
