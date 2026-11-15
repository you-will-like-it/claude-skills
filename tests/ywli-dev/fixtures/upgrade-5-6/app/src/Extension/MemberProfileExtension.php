<?php

namespace App\Extension;

use SilverStripe\Forms\FieldList;
use SilverStripe\Forms\TextField;
use SilverStripe\ORM\DataExtension;
use SilverStripe\ORM\ValidationResult;

class MemberProfileExtension extends DataExtension
{
    private static $db = [
        'Position' => 'Varchar(100)',
    ];

    public function updateCMSFields(FieldList $fields)
    {
        $fields->addFieldToTab('Root.Main', TextField::create('Position', 'Pozicija'));
    }

    public function validate(ValidationResult $validationResult)
    {
        if (strlen((string) $this->getOwner()->Position) > 100) {
            $validationResult->addFieldError('Position', 'Predugo');
        }
    }
}
