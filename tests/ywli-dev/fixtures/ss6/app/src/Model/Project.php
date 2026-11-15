<?php

namespace App\Model;

use SilverStripe\ORM\DataObject;

class Project extends DataObject
{
    private static $table_name = 'App_Project';

    private static $db = [
        'Title' => 'Varchar(255)',
        'Status' => "Enum('Draft,Active,Featured','Draft')",
    ];
}
