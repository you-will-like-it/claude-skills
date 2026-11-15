# SilverStripe 3 — referenca (ss-version-aware)

Pročitaj prije pisanja koda u projektu na SilverStripe 3. Sadrži samo ono što se razlikuje od 4/5/6 ili što modeli često pomiješaju — nije potpuni API priručnik.
Ciljna verzija je 3.7 (posljednja 3.x). Provjereno na granama `3` repozitorija framework (kod = tag 3.7.7), cms (3.7.x), siteconfig i installer; admin (`LeftAndMain`, `ModelAdmin`) je u 3 dio frameworka (`framework/admin`).
Najčešća greška u 3 je kod iz SS4+: `namespace`/`use SilverStripe\...`, `PageController`, `protected function init()`, `.env`, `Config::modify()`, `addFieldError()`. Ništa od toga u 3 ne postoji. Za 3 nema migracione mape u ovom skillu — svaka stavka ispod ima vlastiti izvor.

## Osnovno

- PHP: framework 3.7 traži `^5.3.3 || ^7`; PHP 7.2/7.3 tek od 3.7.3, PHP 7.4 od 3.7.4 (uz brojna deprecation upozorenja — `error_reporting(E_ALL & ~E_DEPRECATED)` u `_ss_environment.php`); PHP 8 nije podržan. Kod piši za PHP verziju projekta (`array()` i string imena klasa rade svugdje). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/composer.json , https://github.com/silverstripe/silverstripe-framework/blob/3.7.7/docs/en/00_Getting_Started/00_Server_Requirements.md , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/00_Getting_Started/00_Server_Requirements.md , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.7.4.md
- Na PHP 7.2+ je `object` rezervisana riječ: bazna klasa je `SS_Object` (3.7), ne `Object` (alias `Object` se učitava samo na PHP < 7.2). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.7.0.md , https://github.com/silverstripe/silverstripe-framework/blob/3/model/fieldtypes/compat/autoload.php
- Moduli su direktoriji u korijenu projekta (`framework/`, `cms/`, `siteconfig/`, `reports/`, `themes/simple`), ne `vendor/`; installer 3 traži `cms`, `framework`, `reports`, `siteconfig` iste verzije i temu `simple` 3.1. Izvor: https://github.com/silverstripe/silverstripe-installer/blob/3/composer.json , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/00_Getting_Started/04_Directory_Structure.md
- Struktura: `mysite/code` (PHP), `mysite/_config.php`, `mysite/_config/*.yml`, `mysite/templates`, `themes/<tema>/templates` (`Layout/`, `Includes/`), `assets/`; web root je korijen projekta (nema `public/`). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/00_Getting_Started/04_Directory_Structure.md
- Klase se nalaze skeniranjem fajlova (`ClassManifest`), ne PSR-4: ime fajla nije bitno i jedan fajl smije imati više klasa, ali nova klasa traži `?flush=1`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/core/manifest/ClassManifest.php
- `Page` i `Page_Controller` su u `mysite/code/`; kontroler za `HomePage` mora se zvati `HomePage_Controller` — `ModelAsController` traži samo `<Klasa>_Controller` (nema `controller_name`), a `HomePageController` se tiho ignoriše i koristi se `Page_Controller`. Izvor: https://github.com/silverstripe/silverstripe-installer/blob/3/mysite/code/Page_Controller.php , https://github.com/silverstripe/silverstripe-cms/blob/3/code/controllers/ModelAsController.php
- CLI: `framework/sake dev/build "flush=1"`, `framework/sake dev/tasks/<ImeKlase>`; u browseru `/dev/build?flush=1`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/17_CLI/index.md

## Namespace-ovi i klase

SS3 nema namespace-a: sve framework/cms klase koje koristiš su globalne. Ne dodaj `namespace App\...` ni `use SilverStripe\...` linije; klasu referenciraj imenom, a u relacijama i YAML-u kao string (`'Member'`). Kolona FQCN zato nema vrijednost; link vodi na fajl koji klasu definiše.

| Klasa | Namespace (FQCN) | Izvor |
|---|---|---|
| `SS_Object` (bazna klasa; ne `Object`) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/core/Object.php |
| `DataObject` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/DataObject.php |
| `DataList` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/DataList.php |
| `DataExtension` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/DataExtension.php |
| `Extension` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/core/Extension.php |
| `ViewableData` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/view/ViewableData.php |
| `ArrayData` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/view/ArrayData.php |
| `ArrayList` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/ArrayList.php |
| `PaginatedList` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/core/PaginatedList.php |
| `SS_List` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/List.php |
| `SS_Map` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/Map.php |
| `ValidationResult` (`error()`, `valid()`) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/ValidationResult.php |
| `ValidationException` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/ValidationException.php |
| `SS_Datetime` (u `$db` piši `'Datetime'`) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/fieldtypes/Datetime.php |
| `SQLSelect` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/queries/SQLSelect.php |
| `DB` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/DB.php |
| `Versioned` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/Versioned.php |
| `Image` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/model/Image.php |
| `File` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/filesystem/File.php |
| `Form` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/forms/Form.php |
| `FieldList` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/forms/FieldList.php |
| `RequiredFields` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/forms/RequiredFields.php |
| `UploadField` (u frameworku) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/forms/UploadField.php |
| `GridField` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/forms/gridfield/GridField.php |
| `GridFieldConfig_RecordEditor` (u `GridFieldConfig.php`) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/forms/gridfield/GridFieldConfig.php |
| `Controller` (`init()` je `public`) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/control/Controller.php |
| `SS_HTTPRequest` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/control/HTTPRequest.php |
| `SS_HTTPResponse` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/control/HTTPResponse.php |
| `Session` (statički `get()`/`set()`) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/control/Session.php |
| `Director` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/control/Director.php |
| `Config` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/core/Config.php |
| `Injector` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/control/injector/Injector.php |
| `Requirements` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/view/Requirements.php |
| `SSViewer` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/view/SSViewer.php |
| `BuildTask` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/dev/BuildTask.php |
| `SS_Log` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/dev/Log.php |
| `SS_Cache` (Zend_Cache) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/cache/Cache.php |
| `Member` (`Member::currentUser()`) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/security/Member.php |
| `Permission` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/security/Permission.php |
| `ModelAdmin` (u frameworku) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/admin/code/ModelAdmin.php |
| `LeftAndMainExtension` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-framework/blob/3/admin/code/LeftAndMainExtension.php |
| `SiteTree` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-cms/blob/3/code/model/SiteTree.php |
| `SiteTreeExtension` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-cms/blob/3/code/model/SiteTreeExtension.php |
| `ContentController` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-cms/blob/3/code/controllers/ContentController.php |
| `SiteConfig` | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-siteconfig/blob/3/code/model/SiteConfig.php |
| `Page_Controller` (projektni kod) | — (globalni, bez namespace-a) | https://github.com/silverstripe/silverstripe-installer/blob/3/mysite/code/Page_Controller.php |

## Potpisi i obrasci

**DataObject** — tabela = ime klase (nema `$table_name`); `validate()` vraća `ValidationResult` i greške dodaje preko `error()`.

```php
class Project extends DataObject
{
    private static $db = array(
        'Title' => 'Varchar(255)',
        'Status' => "Enum('Draft,Active','Draft')",
        'Deadline' => 'Datetime',   // framework/_config.php mapira na SS_Datetime; isti zapis radi i u 4
        'Summary' => 'Text',
    );
    private static $has_one = array('Owner' => 'Client');
    private static $has_many = array('Tasks' => 'Task');   // Task: has_one 'Project' => 'Project'
    private static $many_many = array('Tags' => 'Tag');

    public function getCMSFields()
    {
        $fields = parent::getCMSFields();
        // isto ime kao scaffoldano polje => zamjenjuje ga
        $fields->addFieldToTab('Root.Main', TextareaField::create('Summary', 'Sažetak'));
        return $fields;
    }

    public function validate()   // u DataObject je protected; public je dozvoljen
    {
        $result = parent::validate();
        if (!$this->Title) {
            $result->error('Naslov je obavezan');   // nema addError()/addFieldError()
        }
        return $result;
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/model/DataObject.php , https://github.com/silverstripe/silverstripe-framework/blob/3/model/ValidationResult.php , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/00_Model/09_Validation.md
Napomena: statički config mora biti `private static` (od 3.1). `beforeUpdateCMSFields()` postoji i u 3 ako polja trebaju biti vidljiva extensionima. U `Page` podklasi `onAfterWrite()`, `onBeforeDelete()`, `onAfterDelete()` i `requireDefaultRecords()` moraju biti `public` (SiteTree), `onBeforeWrite()` je `protected`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.1.0.md , https://github.com/silverstripe/silverstripe-cms/blob/3/code/model/SiteTree.php

**DataExtension** — hookovi su `public` (`extend()` ih poziva izvana); vlasnik je `$this->owner`.

```php
class MemberProfileExtension extends DataExtension
{
    private static $db = array('Position' => 'Varchar(100)');

    public function updateCMSFields(FieldList $fields)
    {
        $fields->addFieldToTab('Root.Main', TextField::create('Position', 'Pozicija'));
    }

    public function validate(ValidationResult $validationResult)
    {
        if (strlen($this->owner->Position) > 100) {
            $validationResult->error('Pozicija je preduga');
        }
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/model/DataExtension.php , https://github.com/silverstripe/silverstripe-framework/blob/3/core/Object.php , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/05_Extending/01_Extensions.md
Napomena: kontroler extension (`extends Extension`): `onBeforeInit()`/`onAfterInit()`; `LeftAndMain`/`ModelAdmin` extension: `public function init()`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/admin/code/LeftAndMain.php

**Page_Controller / Controller** — `init()` je `public` i mora zvati `parent::init()` (`protected` je fatalno); akcije u `$allowed_actions`, form akcije ne.

```php
class ContactPage extends Page
{
}

class ContactPage_Controller extends Page_Controller
{
    private static $allowed_actions = array('ContactForm');

    public function init()
    {
        parent::init();
        Requirements::css('mysite/css/contact.css');
    }

    public function ContactForm()
    {
        $fields = FieldList::create(EmailField::create('Email', 'E-mail'));
        $actions = FieldList::create(FormAction::create('doSubmit', 'Pošalji'));
        return Form::create($this, 'ContactForm', $fields, $actions, RequiredFields::create('Email'));
    }

    public function doSubmit($data, Form $form)
    {
        $form->sessionMessage('Hvala!', 'good');   // tip je obavezan argument
        return $this->redirectBack();
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/control/Controller.php , https://github.com/silverstripe/silverstripe-framework/blob/3/forms/Form.php , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/03_Forms/00_Introduction.md
Napomena: akcije primaju `SS_HTTPRequest $request`; sesija je statička: `Session::get('x')` / `Session::set('x', $v)`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/02_Controllers/01_Introduction.md

**GridField** u `getCMSFields()`:

```php
$fields->addFieldToTab('Root.Tasks', GridField::create('Tasks', 'Zadaci', $this->Tasks(), GridFieldConfig_RecordEditor::create(20)));
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/forms/gridfield/GridField.php , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/03_Forms/Field_types/04_GridField.md

**CMS validator** — u 3 samo `getCMSValidator()` (čitaju ga `LeftAndMain` za stranice i `ModelAdmin` za detail formu); `getCMSCompositeValidator()` ne postoji.

```php
public function getCMSValidator()
{
    return RequiredFields::create('Title');
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/admin/code/LeftAndMain.php , https://github.com/silverstripe/silverstripe-framework/blob/3/admin/code/ModelAdmin.php

**BuildTask** — `run($request)` bez tipa parametra; URL je ime klase (`dev/tasks/CleanupTask`), osim ako je zadan `private static $segment`.

```php
class CleanupTask extends BuildTask
{
    protected $title = 'Čišćenje';
    protected $description = 'Briše stare zapise';
    protected $enabled = true;   // false = isključen

    public function run($request)   // $request je SS_HTTPRequest
    {
        if ($request->getVar('dry-run')) {
            DB::alteration_message('Dry run');
            return;
        }
        // ...
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/dev/BuildTask.php , https://github.com/silverstripe/silverstripe-framework/blob/3/dev/TaskRunner.php

**ModelAdmin** — nema `getGridFieldConfig()` ni `$menu_icon_class`; GridField se mijenja u `getEditForm()`, ikona je putanja do slike.

```php
class ProjectAdmin extends ModelAdmin
{
    private static $managed_models = array('Project');
    private static $url_segment = 'projects';
    private static $menu_title = 'Projekti';
    private static $menu_icon = 'mysite/images/projects.png';

    public function getEditForm($id = null, $fields = null)
    {
        $form = parent::getEditForm($id, $fields);
        $gridField = $form->Fields()->fieldByName($this->sanitiseClassName($this->modelClass));
        if ($gridField) {
            $gridField->getConfig()->addComponent(new GridFieldFilterHeader());
        }
        return $form;
    }
}
```

Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/15_Customising_the_Admin_Interface/01_ModelAdmin.md , https://github.com/silverstripe/silverstripe-framework/blob/3/admin/code/ModelAdmin.php

## Config/YAML

```yaml
---
Name: mysite-extensions
After:
  - 'framework/*'
  - 'cms/*'
---
Member:
  extensions:
    - MemberProfileExtension
Project:
  extensions:
    - Versioned("Stage","Live")
SSViewer:
  theme: 'simple'
---
Name: mysite-live
Only:
  environment: 'live'
---
Injector:
  ApiClient:
    properties:
      Timeout: 10
```

Izvor: https://github.com/silverstripe/silverstripe-installer/blob/3/mysite/_config/config.yml , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/05_Extending/01_Extensions.md , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/00_Model/10_Versioning.md , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/05_Extending/05_Injector.md
Napomena: YAML ključevi su gola imena klasa (`Member:`, `Injector:`). Injector u 3 ne zamjenjuje `` `KONSTANTA` `` u backtickovima (to je 4+) — vrijednosti iz okruženja postavi u `_config.php`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/control/injector/Injector.php

- `mysite/_config.php` (PHP config, izvršava se pri svakom zahtjevu): `global $project; $project = 'mysite'; global $database; $database = ''; require_once 'conf/ConfigureFromEnv.php';`, plus npr. `i18n::set_locale('en_US');`, `Member::add_extension('X');`, `Member::set_password_validator($pv);`. Izvor: https://github.com/silverstripe/silverstripe-installer/blob/3/mysite/_config.php , https://github.com/silverstripe/silverstripe-framework/blob/3/security/PasswordValidator.php
- `After`/`Before` se pišu kao putanje `modul/fajl#ime`: `'framework/*'`, `'cms/*'`, `'#coreroutes'`, `'framework/routes#coreroutes'`; imena u frameworku: `#coreconfig`, `#coreroutes`, `#rootroutes`, `#adminroutes`, `#requestprocessors`; cms: `#modelascontrollerroutes`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/04_Configuration/00_Configuration.md , https://github.com/silverstripe/silverstripe-framework/tree/3/_config , https://github.com/silverstripe/silverstripe-cms/tree/3/_config
- `Only`/`Except` pravila: `classexists`, `moduleexists`, `environment`, `envvarset`, `constantdefined` (nema `envorconstant` ni `extensionloaded`). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/core/manifest/ConfigManifest.php
- Config u PHP-u: `Config::inst()->get('Klasa', 'x')`, `$this->config()->x` ili `->get('x')`; upis `Config::inst()->update('Klasa', 'x', $v)` ili `$this->config()->x = $v`. `Config::modify()`, `->set()`, `->merge()` i `$this->config()->update()` ne postoje. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/core/Config.php
- Okruženje: `_ss_environment.php` (u korijenu projekta ili bilo kojem roditeljskom direktoriju) s `define()`: `SS_ENVIRONMENT_TYPE`, `SS_DATABASE_CLASS` (`MySQLDatabase` ili `MySQLPDODatabase`), `SS_DATABASE_SERVER`, `SS_DATABASE_USERNAME`, `SS_DATABASE_PASSWORD`, `SS_DATABASE_NAME`, `SS_DEFAULT_ADMIN_USERNAME`/`_PASSWORD`, `SS_SEND_ALL_EMAILS_TO`, `SS_ERROR_LOG`; za `sake` još `$_FILE_TO_URL_MAPPING`. U kodu čitaj konstante (`defined('X') ? X : null`). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/00_Getting_Started/03_Environment_Management.md
- Logging: `SS_Log::log($poruka, SS_Log::ERR)` (+ `SS_Log::add_writer()`); keš: `SS_Cache::factory('ime')` (Zend_Cache). PSR-3 `LoggerInterface` i Symfony cache su tek u 4. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/dev/Log.php , https://github.com/silverstripe/silverstripe-framework/blob/3/cache/Cache.php

## Templati

- Engine je `SSViewer`, templati `*.ss` u `templates/` (`Page.ss`, `Layout/Page.ss`, `Includes/X.ss`) teme ili `mysite/`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/01_Templates/01_Syntax.md , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/01_Templates/05_Template_Inheritance.md
- U petlji: `$First`, `$Last`, `$Middle`, `$FirstLast`, `$Even`/`$Odd`/`$EvenOdd`, `$Pos`, `$FromEnd`, `$TotalItems`, `$Modulus(n)`, `$MultipleOf(n)`. `$IsFirst`/`$IsLast` u 3 ne postoje (dodani u 4.7). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/view/SSViewer.php
- Opseg: `$Up` = prethodni, `$Top` = osnovni; dodatni selektori u izrazu petlje (`<% loop $Children.Sort('Title').First %>`) implicitno dodaju nivo, pa treba `$Up.Up...`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/01_Templates/01_Syntax.md
- Include s argumentima: `<% include MemberDetails Top=$Top, Name=$Name %>`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/01_Templates/01_Syntax.md
- Uslovi: `||` i `&&`; poređenja `==`, `!=`, `<`, `>`, `<=`, `>=`; `<% if not $X %>`. Nema `or`/`and` (parser odbija, iako docs-3 tvrdi suprotno). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/view/SSTemplateParser.php.inc
- `<% control $X %>` još radi, ali je zastario (deprecation notice) — piši `<% loop $X %>` / `<% with $X %>`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/view/SSTemplateParser.php.inc , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.0.0.md
- Resursi: `$ThemeDir/images/x.png`, `<% require css("mysite/css/x.css") %>`, `<% require themedCSS("layout") %>`, `<% require javascript("mysite/javascript/x.js") %>`; putanje su relativne na korijen projekta. `$resourceURL()`/`$themedResourceURL()` ne postoje. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/01_Templates/03_Requirements.md , https://github.com/silverstripe/silverstripe-framework/blob/3/view/ViewableData.php
- i18n: `<%t Namespace.KEY "Zdravo {name}" name=$Name %>` (radi u 3–6); u PHP-u `_t('Klasa.KEY', 'Default')`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/13_i18n/index.md
- Slike: `$Image.ScaleWidth(200)`, `$Image.Fill(100,100)`, `$Image.Fit(..)`, `$Image.Pad(..)` (rade i u 4); `SetWidth()`/`CroppedImage()` su zastarjeli. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/model/Image.php

## Česte greške

Format: **Ne** (kod iz SS4+) → **Da** (SilverStripe 3.7). Za 3 nema `M`-ID stavki; izvor je naveden uz svaku stavku. Smjer je uvijek "novije → 3".

Kod iz SS4+ (u 3 ne postoji ili je fatalno):

- Ne: `namespace App\Model;` + `use SilverStripe\ORM\DataObject;` → Da: bez namespace-a i `use` linija, `extends DataObject`. Relacije po konvenciji 3 kao string `'Owner' => 'Member'` (`Member::class` daje isti string, ali tek od PHP 5.5). Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#literal-class-names
- Ne: `private static $table_name = 'App_Project'` → Da: izostavi — u 3 je tabela uvijek ime klase, config se ignoriše. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#literal-table-names
- Ne: `PageController` / `HomePageController` → Da: `Page_Controller` / `HomePage_Controller` (inače se tiho koristi roditeljski kontroler). Izvor: https://github.com/silverstripe/silverstripe-cms/blob/3/code/controllers/ModelAsController.php
- Ne: `protected function init()` → Da: `public function init()` (`Controller::init()` i `ContentController::init()` su `public` — `protected` je fatalno). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/control/Controller.php
- Ne: `protected function onAfterWrite()` / `onBeforeDelete()` u `Page` podklasi → Da: `public` (u `SiteTree` 3 su public). Izvor: https://github.com/silverstripe/silverstripe-cms/blob/3/code/model/SiteTree.php
- Ne: `HTTPRequest`, `HTTPResponse` → Da: `SS_HTTPRequest`, `SS_HTTPResponse`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/control/HTTPRequest.php
- Ne: `$result->addError('x')` / `addFieldError('Polje', 'x')` / `isValid()` → Da: `$result->error('x')` / `valid()` (nema grešaka po polju). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/model/ValidationResult.php
- Ne: `DBDatetime::now()` → Da: `SS_Datetime::now()`; u `$db` piši `'Datetime'` (`SS_Object::useCustomClass('Datetime', 'SS_Datetime', true)` — radi u 3 i 4), ne `'SS_Datetime'` (u 4 ne postoji). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/_config.php , https://github.com/silverstripe/silverstripe-framework/blob/3/model/fieldtypes/Datetime.php
- Ne: `Security::getCurrentUser()` / `Security::setCurrentUser($m)` → Da: `Member::currentUser()` / `Member::currentUserID()` / `$member->logIn()`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/security/Member.php
- Ne: `$request->getSession()->get('x')` → Da: `Session::get('x')` / `Session::set('x', $v)`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#session
- Ne: `Config::modify()->set(...)`, `$this->config()->update(...)`/`set()`/`merge()` → Da: `Config::inst()->update('Klasa', 'x', $v)` ili `$this->config()->x = $v`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/core/Config.php
- Ne: `.env`, `Environment::getEnv('X')` → Da: `_ss_environment.php` s `define('X', ...)` i čitanje konstante. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#overview
- Ne: `app/src`, `app/_config`, `public/`, `vendor/silverstripe/...` → Da: `mysite/code`, `mysite/_config`, web root = korijen, moduli u korijenu (`framework/`, `cms/`). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/00_Getting_Started/04_Directory_Structure.md
- Ne: YAML `SilverStripe\Core\Injector\Injector:`, `SilverStripe\Security\Member:` → Da: `Injector:`, `Member:`; `Versioned::class`/`SilverStripe\Versioned\Versioned` → `Versioned("Stage","Live")`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/00_Model/10_Versioning.md
- Ne: `private static $owns` + `publishRecursive()` → Da: nema ownership API-ja; objavi svaki zapis: `$page->doPublish()` ili `$obj->publish('Stage', 'Live')`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/model/Versioned.php , https://github.com/silverstripe/silverstripe-cms/blob/3/code/model/SiteTree.php
- Ne: `many_many` s `'through'`, `private static $cascade_deletes` / `$cascade_duplicates` (4+) → Da: u 3 ne postoje; polja na samoj vezi preko `private static $many_many_extraFields`, povezane zapise briši ručno (npr. u `onBeforeDelete()`). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/model/DataObject.php , https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/03_Forms/Field_types/04_GridField.md , https://docs.silverstripe.org/en/4/developer_guides/model/relations/#cascading-deletions
- Ne: `getCMSCompositeValidator()` → Da: `getCMSValidator()`; ModelAdmin `getGridFieldConfig()` → `getEditForm()`; `$menu_icon_class` → `$menu_icon` (putanja). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/admin/code/ModelAdmin.php
- Ne: `$IsFirst`/`$IsLast`, `$resourceURL()`, `$themedResourceURL()` → Da: `$First`/`$Last`, `$ThemeDir`, `<% require themedCSS() %>`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/view/SSViewer.php
- Ne: `Requirements::css('silverstripe/admin:client/...')`, `'app/css/x.css'` → Da: putanja od korijena projekta: `'mysite/css/x.css'`, `'themes/simple/css/x.css'`, `THIRDPARTY_DIR . '/jquery/jquery.js'`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/01_Templates/03_Requirements.md , https://docs.silverstripe.org/en/4/changelogs/4.0.0/#module-paths
- Ne: `'`MY_API_KEY`'` u Injector YAML-u → Da: postavi vrijednost u `_config.php` iz konstante. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/control/injector/Injector.php
- Ne: `vendor/bin/sake`, `sake dev/tasks/App-Tasks-CleanupTask` → Da: `framework/sake dev/tasks/CleanupTask`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/17_CLI/index.md
- Ne: `Psr\Log\LoggerInterface` preko Injectora, Symfony `CacheInterface` → Da: `SS_Log::log()`, `SS_Cache::factory()`. Izvor: https://docs.silverstripe.org/en/4/changelogs/4.0.0/#psr3-logging , https://docs.silverstripe.org/en/4/changelogs/4.0.0/#cache
- Ne: `protected` hook u `Extension`/`DataExtension` (5.0+) → Da: `public` (u 3 `extend()` poziva `$instance->$method(...)`). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/core/Object.php
- Ne: `Email` + `MAILER_DSN`/`Swift_*` Injector config → Da: 3 koristi vlastiti `Mailer` (PHP `mail()`): `$email = new Email($from, $to, $subject, $body); $email->send();`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/02_Developer_Guides/10_Email/index.md

Zastarjelo u 3.7 (radi, ali piši ispravni 3.7 oblik — gdje postoji, isti radi i u 4):

- Ne: `extends Object`, `Object::has_extension()` → Da: `SS_Object` (obavezno na PHP 7.2+; u 4 nema bazne klase — traitovi `Injectable`/`Configurable`/`Extensible`). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.7.0.md
- Ne: `<% control %>` → Da: `<% loop %>` / `<% with %>`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.0.0.md
- Ne: `SetWidth()`, `CroppedImage()` → Da: `ScaleWidth()`, `Fill()`. Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/model/Image.php
- Ne: `public static $db` / `public static $allowed_actions` → Da: `private static` (javni statički config se ne čita od 3.1). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.1.0.md
- Ne: `SQLQuery` → Da: `SQLSelect` (od 3.2; jedini oblik u 4). Izvor: https://github.com/silverstripe/silverstripe-framework/blob/3/docs/en/04_Changelogs/3.2.0.md
