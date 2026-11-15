<?php

namespace App\Model;

use SilverStripe\Forms\CompositeValidator;
use SilverStripe\Forms\RequiredFields;
use SilverStripe\ORM\ArrayList;
use SilverStripe\ORM\DataObject;
use SilverStripe\ORM\ValidationResult;
use SilverStripe\View\ArrayData;

class Project extends DataObject
{
    private static $table_name = 'App_Project';

    private static $db = [
        'Title' => 'Varchar(255)',
        'Status' => "Enum('Draft,Active','Draft')",
    ];

    public function getCMSCompositeValidator(): CompositeValidator
    {
        $validator = parent::getCMSCompositeValidator();
        $validator->addValidator(RequiredFields::create(['Title']));
        return $validator;
    }

    public function validate()
    {
        $result = parent::validate();
        if (!$this->Title) {
            $result->addFieldError('Title', 'Naslov je obavezan');
        }
        return $result;
    }

    public function StatusOptions(): ArrayList
    {
        $list = ArrayList::create();
        foreach (['Draft', 'Active'] as $status) {
            $list->push(ArrayData::create(['Name' => $status]));
        }
        return $list;
    }
}
