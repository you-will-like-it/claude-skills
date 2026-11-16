<?php

namespace YouWillLikeIT\Example\Model;

use SilverStripe\ORM\DataObject;

class Widget extends DataObject
{
    private static $table_name = 'YWLI_Widget';

    private static $db = [
        'Title' => 'Varchar(255)',
    ];
}
