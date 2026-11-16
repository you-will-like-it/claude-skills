# SilverStripe 6 — referenca (ss-version-aware)

Pročitaj prije pisanja koda u projektu na CMS 6. Sadrži samo ono što se razlikuje od 4/5 ili što modeli često pomiješaju — nije potpuni API priručnik.
Provjereno na granama `6` (framework, cms, siteconfig), `3` (admin, assets, asset-admin, versioned) i `1` (template-engine, htmleditor-tinymce), stanje CMS 6.3 (6.4 u razvoju).
Svaka API stavka ispod postoji u tom izvoru; za prelazak sa 5 koristi `migrations/5-to-6.md` (ID-evi `M56-NNN`).

## Osnovno

- PHP 8.3–8.4 za CMS 6.0–6.1, PHP 8.3–8.5 za 6.2+; MySQL 8.0+ (MySQL 5 nije podržan). Izvor: https://docs.silverstripe.org/en/6/getting_started/server_requirements/#php-support , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#mysql-5-support
- Moduli: `silverstripe/framework` 6, `cms` 6, `admin` 3, `assets` 3, `versioned` 3, `asset-admin` 3, `siteconfig` 6, `errorpage` 3, `reports` 6, `session-manager` 3, `template-engine` 1. `recipe-core` 6 = framework, assets, config, mimevalidator, template-engine; ostali CMS moduli (i versioned) dolaze iz `recipe-cms` 6. Izvor: https://github.com/silverstripe/recipe-core/blob/6/composer.json , https://github.com/silverstripe/recipe-cms/blob/6/composer.json
- TinyMCE je zaseban modul: `silverstripe/htmleditor-tinymce` mora biti eksplicitno u `composer.json` (installer ga ima). `silverstripe/campaign-admin` i GraphQL više nisu dio `recipe-cms`. Izvor: https://github.com/silverstripe/silverstripe-installer/blob/6/composer.json , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#campaign-admin , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#graphql-removed
- Struktura: `app/src` (PHP), `app/_config/*.yml`, `app/templates` (tema `$default`), `themes/<tema>/templates`, web root `public/` (`public/assets`, `public/_resources`), `.env` u korijenu projekta. Zadana tema installera je `startup-theme`. Izvor: https://docs.silverstripe.org/en/6/getting_started/directory_structure/
- `Page` i `PageController` su u globalnom namespaceu (`app/src/Page.php`, `app/src/PageController.php`); kontroler stranice `App\PageType\HomePage` je `App\PageType\HomePageController` (ili config `controller_name`). Izvor: https://github.com/silverstripe/recipe-cms/blob/6/app/src/PageController.php , https://docs.silverstripe.org/en/6/developer_guides/controllers/introduction/#connecting-pages-to-controllers
- CLI je `symfony/console`: `vendor/bin/sake db:build --flush`, `sake flush`, `sake tasks`, `sake tasks:<ime-taska>`; HTTP i dalje `/dev/build?flush=1`, `/dev/tasks/<ime>`. Izvor: https://docs.silverstripe.org/en/6/developer_guides/cli/sake/#usage

## Namespace-ovi i klase

Klase koje su se selile između 4/5/6 ili koje modeli često pogriješe. Ime koje nije ovdje provjeri u `vendor/silverstripe/*` prije upotrebe.

| Klasa | Namespace (FQCN) | Izvor |
|---|---|---|
| `DataObject` | `SilverStripe\ORM\DataObject` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/ORM/DataObject.php |
| `DataList` (ostaje u ORM) | `SilverStripe\ORM\DataList` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/ORM/DataList.php |
| `Extension` (i za DataObject; `DataExtension` ne postoji) | `SilverStripe\Core\Extension` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Core/Extension.php |
| `ModelData` (bivši `ViewableData`) | `SilverStripe\Model\ModelData` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/ModelData.php |
| `ArrayData` | `SilverStripe\Model\ArrayData` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/ArrayData.php |
| `ArrayList` | `SilverStripe\Model\List\ArrayList` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/List/ArrayList.php |
| `PaginatedList` | `SilverStripe\Model\List\PaginatedList` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/List/PaginatedList.php |
| `GroupedList` | `SilverStripe\Model\List\GroupedList` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/List/GroupedList.php |
| `SS_List` | `SilverStripe\Model\List\SS_List` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/List/SS_List.php |
| `Map` | `SilverStripe\Model\List\Map` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/List/Map.php |
| `ArrayLib` | `SilverStripe\Core\ArrayLib` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Core/ArrayLib.php |
| `ValidationResult` | `SilverStripe\Core\Validation\ValidationResult` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Core/Validation/ValidationResult.php |
| `ValidationException` | `SilverStripe\Core\Validation\ValidationException` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Core/Validation/ValidationException.php |
| `RequiredFieldsValidator` (bivši `RequiredFields`) | `SilverStripe\Forms\Validation\RequiredFieldsValidator` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Forms/Validation/RequiredFieldsValidator.php |
| `CompositeValidator` | `SilverStripe\Forms\Validation\CompositeValidator` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Forms/Validation/CompositeValidator.php |
| `Validator` | `SilverStripe\Forms\Validation\Validator` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Forms/Validation/Validator.php |
| `BuildTask` (sada `PolyCommand`) | `SilverStripe\Dev\BuildTask` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Dev/BuildTask.php |
| `PolyOutput` | `SilverStripe\PolyExecution\PolyOutput` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/PolyExecution/PolyOutput.php |
| `DbBuild` (umjesto `DevBuildController`) | `SilverStripe\Dev\Command\DbBuild` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Dev/Command/DbBuild.php |
| `SSViewer` (ostaje u View) | `SilverStripe\View\SSViewer` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/View/SSViewer.php |
| `SSTemplateEngine` | `SilverStripe\TemplateEngine\SSTemplateEngine` | https://github.com/silverstripe/silverstripe-template-engine/blob/1/src/SSTemplateEngine.php |
| `HTMLEditorField` (ostaje u framework) | `SilverStripe\Forms\HTMLEditor\HTMLEditorField` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Forms/HTMLEditor/HTMLEditorField.php |
| `TinyMCEConfig` | `SilverStripe\TinyMCE\TinyMCEConfig` | https://github.com/silverstripe/silverstripe-htmleditor-tinymce/blob/1/src/TinyMCEConfig.php |
| `ErrorOutputHandler` (bivši `HTTPOutputHandler`) | `SilverStripe\Logging\ErrorOutputHandler` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Logging/ErrorOutputHandler.php |
| `EntropyPasswordValidator` (zadani) | `SilverStripe\Security\Validation\EntropyPasswordValidator` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Security/Validation/EntropyPasswordValidator.php |
| `RulesPasswordValidator` (bivši `PasswordValidator`) | `SilverStripe\Security\Validation\RulesPasswordValidator` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Security/Validation/RulesPasswordValidator.php |
| `GridFieldConfig_RecordEditor` | `SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor` | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Forms/GridField/GridFieldConfig_RecordEditor.php |
| `SiteTree` | `SilverStripe\CMS\Model\SiteTree` | https://github.com/silverstripe/silverstripe-cms/blob/6/code/Model/SiteTree.php |
| `ContentController` | `SilverStripe\CMS\Controllers\ContentController` | https://github.com/silverstripe/silverstripe-cms/blob/6/code/Controllers/ContentController.php |
| `ModelAdmin` | `SilverStripe\Admin\ModelAdmin` | https://github.com/silverstripe/silverstripe-admin/blob/3/code/ModelAdmin.php |
| `AdminController` (novi; `/admin/*` bez menija/edit forme) | `SilverStripe\Admin\AdminController` | https://github.com/silverstripe/silverstripe-admin/blob/3/code/AdminController.php |
| `SingleRecordAdmin` (novi) | `SilverStripe\Admin\SingleRecordAdmin` | https://github.com/silverstripe/silverstripe-admin/blob/3/code/SingleRecordAdmin.php |
| `UploadField` | `SilverStripe\AssetAdmin\Forms\UploadField` | https://github.com/silverstripe/silverstripe-asset-admin/blob/3/code/Forms/UploadField.php |
| `Image` | `SilverStripe\Assets\Image` | https://github.com/silverstripe/silverstripe-assets/blob/3/src/Image.php |
| `Versioned` | `SilverStripe\Versioned\Versioned` | https://github.com/silverstripe/silverstripe-versioned/blob/3/src/Versioned.php |

## Potpisi i obrasci

**DataObject** — relacije su iste kao u 5; `validate()` mora imati povratni tip; `getCMSFields()` preko `beforeUpdateCMSFields()` da extensioni vide tvoja polja.

```php
namespace App\Model;

use SilverStripe\Core\Validation\ValidationResult;
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
    private static $class_description = 'Projekat klijenta';

    public function getCMSFields()
    {
        $this->beforeUpdateCMSFields(function (FieldList $fields) {
            // isto ime kao scaffoldano polje => zamjenjuje ga
            $fields->addFieldToTab('Root.Main', TextareaField::create('Summary', 'Sažetak'));
        });
        return parent::getCMSFields();
    }

    public function validate(): ValidationResult
    {
        $result = parent::validate();
        if (!$this->Title) {
            $result->addFieldError('Title', 'Naslov je obavezan');
        }
        return $result;
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/6/src/ORM/DataObject.php , https://docs.silverstripe.org/en/6/developer_guides/model/validation/#model-validation
Napomena: `parent::validate()` u 6 već poziva `validate()` svakog `DBField`-a (npr. predug `Varchar` baca `ValidationException` pri `write()`). Relacije se scaffoldaju (zadano `has_many`/`many_many` kao `GridField` u vlastitom tabu; za `SiteTree`, `File`, `Member` i dr. druga polja — M56-123) — u 6 i na `Page` klasama. Polja koja ne želiš ukloni s `scaffold_cms_fields_settings` (`ignoreFields`, `restrictFields`, `restrictRelations`) ili `$fields->removeByName()`. Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#sitetree-scaffolding

**Extension** — uvijek `SilverStripe\Core\Extension`; hookovi preporučeno `protected`; owner preko `$this->getOwner()`.

```php
namespace App\Extension;

use SilverStripe\Core\Extension;
use SilverStripe\Core\Validation\ValidationResult;
use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\TextField;

class MemberProfileExtension extends Extension
{
    private static $db = ['Position' => 'Varchar(100)'];

    protected function updateCMSFields(FieldList $fields)
    {
        $fields->addFieldToTab('Root.Main', TextField::create('Position', 'Pozicija'));
    }

    protected function updateValidate(ValidationResult $result)   // u 5: validate()
    {
        if (strlen((string) $this->getOwner()->Position) > 100) {
            $result->addFieldError('Position', 'Predugo');
        }
    }

    protected function onAfterPopulateDefaults() {}   // u 5: populateDefaults()
    protected function onRequireDefaultRecords() {}   // u 5: requireDefaultRecords()
}
```

Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#hooks-renamed , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#hooks-protected , https://docs.silverstripe.org/en/6/developer_guides/extending/extensions/#modifying-existing-methods
Napomena: `onBeforeWrite`, `onAfterWrite`, `onBeforeDelete`, `updateCMSFields`, `updateCMSCompositeValidator` imaju ista imena; novo u 6: `updateCMSEditLink` (iz `DataObject::getCMSEditLink()`); `LeftAndMain`/`ModelAdmin` extension: `onInit()` (u 5: `init()`); kontroler extension: `onBeforeInit()`/`onAfterInit()`.

**PageController / Controller** — `init()` je `protected` i mora zvati `parent::init()`; akcije u `$allowed_actions`, form akcije (`doSubmit`) ne.

```php
namespace App\PageType;

use PageController;
use SilverStripe\Control\HTTPResponse;
use SilverStripe\Core\Validation\ValidationResult;
use SilverStripe\Forms\EmailField;
use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\Form;
use SilverStripe\Forms\FormAction;
use SilverStripe\Forms\Validation\RequiredFieldsValidator;

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
        return Form::create($this, 'ContactForm', $fields, $actions, RequiredFieldsValidator::create('Email'));
    }

    public function doSubmit(array $data, Form $form): HTTPResponse
    {
        $form->sessionMessage('Hvala!', ValidationResult::TYPE_GOOD);
        return $this->redirectBack();
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/6/src/Control/Controller.php , https://docs.silverstripe.org/en/6/developer_guides/forms/introduction/
Napomena: `Controller::curr()` vraća `?Controller` (bez izuzetka), `render()` vraća `DBHTMLText`, `redirect()`/`redirectBack()` vraćaju `HTTPResponse`.

**GridField** u `getCMSFields()` (ručno, npr. s drugim configom od scaffoldanog):

```php
// use SilverStripe\Forms\GridField\GridField; use SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor;
$fields->addFieldToTab('Root.Tasks', GridField::create('Tasks', 'Zadaci', $this->Tasks(), GridFieldConfig_RecordEditor::create(20)));
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/6/src/Forms/GridField/GridField.php , https://docs.silverstripe.org/en/6/developer_guides/forms/field_types/gridfield/
Napomena: `FieldList::addFieldToTab(string, FormField, ?string)`, `addFieldsToTab(string, array, ?string)` — drugi argument mora biti `array` (vidi M56-077).

**CMS validator** — `getCMSValidator()` se više ne poziva:

```php
public function getCMSCompositeValidator(): CompositeValidator   // SilverStripe\Forms\Validation\CompositeValidator
{
    $validator = parent::getCMSCompositeValidator();
    $validator->addValidator(RequiredFieldsValidator::create(['Title']));   // SilverStripe\Forms\Validation\RequiredFieldsValidator
    return $validator;
}
```

Izvor: https://docs.silverstripe.org/en/6/developer_guides/forms/validation/ , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#getcmsvalidator

**BuildTask** — `execute()` umjesto `run($request)`; ne registruje se, dovoljno je da klasa postoji.

```php
namespace App\Tasks;

use SilverStripe\Dev\BuildTask;
use SilverStripe\PolyExecution\PolyOutput;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;

class CleanupTask extends BuildTask
{
    protected static string $commandName = 'cleanup';          // /dev/tasks/cleanup, sake tasks:cleanup
    protected string $title = 'Čišćenje';
    protected static string $description = 'Briše stare zapise';

    protected function execute(InputInterface $input, PolyOutput $output): int
    {
        if ($input->getOption('dry-run')) {
            $output->writeln('Dry run');
        }
        return Command::SUCCESS;
    }

    public function getOptions(): array
    {
        return [new InputOption('dry-run', null, InputOption::VALUE_NONE, 'Samo prikaži')];
    }
}
```

Izvor: https://docs.silverstripe.org/en/6/developer_guides/cli/polycommand/#buildtask , https://github.com/silverstripe/silverstripe-framework/blob/6/src/Dev/BuildTask.php
Napomena: `$commandName` bez namespacea (`tasks:` se dodaje sam); isključivanje: config `is_enabled: false`.

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
        // $config->addComponent(...) / removeComponentsByType(...)
        return $config;
    }
}
```

Izvor: https://docs.silverstripe.org/en/6/developer_guides/customising_the_admin_interface/modeladmin/ , https://github.com/silverstripe/silverstripe-admin/blob/3/code/ModelAdmin.php
Napomena: `LeftAndMain.tree_class` je sada `model_class`; za jedan zapis (kao SiteConfig) koristi `SingleRecordAdmin`. Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#leftandmain-refactor

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
  SilverStripe\Security\Validation\PasswordValidator:
    class: 'SilverStripe\Security\Validation\RulesPasswordValidator'   # vraća pravila iz CMS 5
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

Izvor: https://docs.silverstripe.org/en/6/developer_guides/extending/extensions/ , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#password-validation , https://docs.silverstripe.org/en/6/developer_guides/extending/injector/#using-constants-and-environment-variables

- `Only`/`Except` pravila: `classexists`, `moduleexists`, `environment` (`dev`/`test`/`live`), `envvarset`, `constantdefined`, `envorconstant`, `extensionloaded`. Izvor: https://docs.silverstripe.org/en/6/developer_guides/configuration/configuration/#exclusionary-rules
- Česta `After`/`Before` imena u core-u (`Name:` u `_config` modula): framework `#coreconfig`, `#corepasswords`, `#coreroutes`, `#rootroutes`, `#logging`, `#mailer`, `#corecache`, `#view-config`; cms `#cmsextensions`, `#modelascontrollerroutes`; admin `#adminroutes`; assets `#assetsflysystem`. Izvor: https://github.com/silverstripe/silverstripe-framework/tree/6/_config , https://github.com/silverstripe/silverstripe-cms/tree/6/_config , https://github.com/silverstripe/silverstripe-admin/tree/3/_config , https://github.com/silverstripe/silverstripe-assets/tree/3/_config , https://docs.silverstripe.org/en/6/developer_guides/configuration/configuration/#before-after-rules
- Template engine je Injector servis: `SilverStripe\View\TemplateEngine` → `SilverStripe\TemplateEngine\SSTemplateEngine`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/6/_config/view.yml
- Logging handler za prikaz grešaka: `class: SilverStripe\Logging\ErrorOutputHandler`. Izvor: https://docs.silverstripe.org/en/6/developer_guides/debugging/error_handling/#setting-a-different-configuration-for-dev
- `.env`: `SS_DATABASE_CLASS="MySQLDatabase"`, `SS_DATABASE_SERVER`, `SS_DATABASE_USERNAME`, `SS_DATABASE_PASSWORD`, `SS_DATABASE_NAME`, `SS_ENVIRONMENT_TYPE` (`dev`/`test`/`live`), `SS_DEFAULT_ADMIN_USERNAME`/`_PASSWORD`, `SS_BASE_URL`, `MAILER_DSN` (https://docs.silverstripe.org/en/6/developer_guides/email/), `SS_ALLOWED_HOSTS`, `SS_TRUSTED_PROXY_IPS`. Novo u 6: `SS_IN_MEMORY_CACHE_FACTORY`, `SS_SESSION_SAVE_HANDLER_CLASS`, `SS_SESSION_CACHE_FACTORY`. Izvor: https://docs.silverstripe.org/en/6/getting_started/environment_management/#core-environment-variables
- Zadano u 6: utf8mb4 (ne postavljaj `charset` ručno), session cookie `Secure` + `SameSite=Strict`, `CanonicalURLMiddleware` u svim okruženjima, bez zadanog APCu in-memory cachea. Vidi M56-093, M56-090, M56-091, M56-121.

## Templati

- Default engine je `SSTemplateEngine` (modul `silverstripe/template-engine`), sintaksa `.ss` ostaje ista. Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#view-layer-abstraction
- U petlji: `$IsFirst`, `$IsLast`, `$Middle`, `$FirstLast`, `$Even`/`$Odd`/`$EvenOdd`, `$Pos`, `$FromEnd`, `$TotalItems`, `$Modulus(n)`, `$MultipleOf(n)` — nema `$First`/`$Last`. Izvor: https://docs.silverstripe.org/en/6/developer_guides/templates/syntax/#position-indicators
- `<% loop %>`/`<% with %>` uvode tačno jedan nivo opsega: `$Up` = prethodni opseg, `$Top` = osnovni (kontroler/stranica). Izvor: https://docs.silverstripe.org/en/6/developer_guides/templates/syntax/#up
- Include ne vidi roditeljski opseg — proslijedi argumente: `<% include MemberDetails Top=$Top, Name=$Name %>` (`templates/Includes/MemberDetails.ss`). Izvor: https://docs.silverstripe.org/en/6/developer_guides/templates/syntax/#includes
- Novo u 6: varijabla kao argument (`$Foo($Bar)` šalje vrijednost `Bar`), argumenti se prosljeđuju i getterima (`$MyField(1,2)` → `getMyField(1, 2)`), nativni PHP nizovi se mogu loopati. Argumenti zadržavaju tip (`1`, `0.5`, `true`, `null`); stringove piši s navodnicima. Izvor: https://docs.silverstripe.org/en/6/developer_guides/templates/syntax/#variables
- `$Me` / objekat u templatu poziva `forTemplate()`; zadani `ModelData::forTemplate(): string` renderuje template nazvan po klasi. Izvor: https://docs.silverstripe.org/en/6/developer_guides/templates/syntax/#fortemplate
- i18n samo `<%t Namespace.KEY "Zdravo {name}" name=$Name %>`; `<% _t(...) %>` i `sprintf(_t(...))` su uklonjeni (M56-095). Izvor: https://docs.silverstripe.org/en/6/developer_guides/i18n/#usage-in-template-files
- Templati form polja: `$FormattedValue` umjesto `$Value` (M56-096), `$SchemaAttributesHtml` za `data-schema` (M56-099). Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#formfield-value , https://docs.silverstripe.org/en/6/changelogs/6.0.0/#formfield-schema-data
- Uslovi: `||` i `&&`; poređenja `==`, `!=`, `<`, `>`, `<=`, `>=`; negacija `<% if not $X %>`. Nema `or`/`and` (parser odbija — parse error). Izvor: https://docs.silverstripe.org/en/6/developer_guides/templates/syntax/#conditional-logic , https://github.com/silverstripe/silverstripe-template-engine/blob/1/src/SSTemplateParser.peg
- `<% base_tag %>` je zastario od 6.2 (config `SSViewer.enable_base_tag: false`). Izvor: https://docs.silverstripe.org/en/6/changelogs/6.2.0/#good-bye-base-tag
- Ime templata u PHP-u bez `.ss` (`setHTMLTemplate('Email/Welcome')`, M56-098). Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/#view-layer-separation

## Česte greške

Format: **Ne** (iz 4/5) → **Da** (CMS 6). ID vodi na stavku u `migrations/5-to-6.md` ili `migrations/4-to-5.md` sa izvorom.

- Ne: `extends DataExtension` / `SiteTreeExtension` / `LeftAndMainExtension` → Da: `extends SilverStripe\Core\Extension` (M56-036, M56-037, M56-038).
- Ne: `SilverStripe\View\ViewableData` → Da: `SilverStripe\Model\ModelData` (M56-011); `View\ArrayData` → `Model\ArrayData` (M56-010).
- Ne: `SilverStripe\ORM\ArrayList` / `PaginatedList` / `GroupedList` / `Map` / `SS_List` / `ListDecorator` → Da: `SilverStripe\Model\List\*` (M56-002 do M56-007). `DataList`, `HasManyList`, `ManyManyList` ostaju u `SilverStripe\ORM`.
- Ne: `SilverStripe\ORM\ValidationResult` / `ValidationException` → Da: `SilverStripe\Core\Validation\*` (M56-008, M56-009); `ORM\ArrayLib` → `Core\ArrayLib` (M56-001).
- Ne: `SilverStripe\Forms\RequiredFields` → Da: `SilverStripe\Forms\Validation\RequiredFieldsValidator` (M56-015); `Forms\Validator`/`Forms\CompositeValidator` → `Forms\Validation\*` (M56-014, M56-016). `FieldsValidator` ne postoji.
- Ne: `public function validate()` bez tipa u DataObject → Da: `public function validate(): ValidationResult` (M56-057).
- Ne: hook `validate($result)` u extensionu → Da: `updateValidate($result)` (M56-059); `populateDefaults` → `onAfterPopulateDefaults` (M56-060); `requireDefaultRecords` → `onRequireDefaultRecords` (M56-061); `flushCache` → `onFlushCache` (M56-062); `LeftAndMain` extension `init` → `onInit` (M56-064).
- Ne: `authenticationFailed`/`MetaTags(&$tags)`/`forgotPassword` hookovi → Da: `onAuthenticationFailed`, `updateMetaTags`, `onForgotPassword` (M56-065, M56-066, M56-067).
- Ne: `getCMSValidator()` → Da: nadjačaj `getCMSCompositeValidator(): CompositeValidator` (M56-050).
- Ne: `CMSEditLink()` → Da: `getCMSEditLink(): ?string` (M56-051).
- Ne: `BuildTask::run($request)`, `private static $segment`, `protected $description`, `protected $enabled` → Da: `execute(InputInterface $input, PolyOutput $output): int`, `protected static string $commandName`, `protected static string $description`, config `is_enabled` (M56-071, M56-078, M56-072, M56-079).
- Ne: `sake dev/build flush=1`, `sake dev/tasks/X` → Da: `sake db:build --flush`, `sake tasks:X` (M56-109).
- Ne: `SilverStripe\Forms\HTMLEditor\TinyMCEConfig` → Da: `SilverStripe\TinyMCE\TinyMCEConfig` + composer `silverstripe/htmleditor-tinymce` (M56-029, M56-102).
- Ne: `SilverStripe\Logging\HTTPOutputHandler` → Da: `SilverStripe\Logging\ErrorOutputHandler` (M56-026).
- Ne: `SilverStripe\Security\PasswordValidator` → Da: `SilverStripe\Security\Validation\RulesPasswordValidator`; zadani je `EntropyPasswordValidator` (M56-017).
- Ne: `public function forTemplate()` bez tipa → Da: `public function forTemplate(): string` (M56-073).
- Ne: `FormField::Value()` → Da: `getValue()` / `getFormattedValue()` / `dataValue()` (M56-047); `FormField::validate($validator): bool` → `validate(): ValidationResult` (M56-058).
- Ne: `SSViewer::fromString()` / `execute_string()` → Da: `Injector::inst()->create(TemplateEngine::class)->renderString($tpl, ViewLayerData::create($data))` (instanca, ne statički; obje klase iz `SilverStripe\View`; M56-040, https://github.com/silverstripe/silverstripe-framework/blob/6/src/Forms/GridField/GridFieldAddExistingAutocompleter.php); `SSViewer.global_key` → `SSTemplateEngine.global_key` (M56-087).
- Ne: `Controller::has_curr()` → Da: `Controller::curr()` i provjera na `null` (M56-046).
- Ne: `DataObject::get($class, $filter, $sort, $join, $limit)` → Da: bez `$join` (M56-113); isto `Versioned::get_by_stage()` (M56-114).
- Ne: nadjačani `write()` sa 4 parametra → Da: dodaj `bool $skipValidation = false` (M56-075); `flushCache(bool $persistent = true): static` (M56-063).
- Ne: `$obj->obj('Nepostojece')->Nice()` → Da: provjeri `null`, `obj()` vraća `null` (M56-076).
- Ne: `PaginatedList::count()` kao ukupan broj → Da: `getTotalItems()` (M56-108).
- Ne: oslanjanje na tiho skraćivanje `Varchar` / int u `Varchar` → Da: ispravan tip i dužina, inače `ValidationException` (M56-107).
- Ne: `SiteTree.description` / `BaseElement.description` (elemental), `icon`, `icon_class`; `LeftAndMain.tree_class` → Da: `class_description`, `cms_icon`, `cms_icon_class`; `model_class` (M56-082, M56-084, M56-081).
- Ne: `ContentController::Menu($level)` u PHP-u → Da: `getMenu($level)`; `$Menu(1)` u templatu radi (M56-115).
- Ne: `ImageManager` `driver: imagick` → Da: Injector servis `InterventionImageDriver` (M56-092).
- Ne (iz CMS 4): `$First`/`$Last` → Da: `$IsFirst`/`$IsLast` (M45-078); `Member::currentUser()` → `Security::getCurrentUser()` (M45-023); `config()->update()` → `merge()`/`set()` (M45-029); `$this->stat('x')` → `$this->config()->get('x')` (M45-028); `Page_Controller` → `PageController` (M45-092).
- Ne (iz CMS 4): `limit(0)` za "bez limita" → Da: `limit(null)` (M45-068); `sort('RAND()')` → `orderBy('RAND()')` (M45-069); SwiftMailer → `MAILER_DSN` (M45-007, M45-070); `$ThemeDir` → `$themedResourceURL()`/`$resourceURL()` (M45-080).
- Zastarjelo u 6.1+ (radi, ali izbjegavaj): `DataObject::get_one()` / `get_by_id()` → `DataObject::get(X::class)->setUseCache(true)->first()` / `->byID($id)` (od 6.1); `FieldList::dataFields()` → `getDataFields()` (od 6.2). Izvor: https://docs.silverstripe.org/en/6/changelogs/6.1.0/#deprecated-api , https://docs.silverstripe.org/en/6/changelogs/6.2.0/#deprecated-api
