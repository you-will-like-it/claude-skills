<?php

declare(strict_types=1);

namespace App\Tasks;

use SilverStripe\Dev\BuildTask;
use SilverStripe\ORM\DataObject;
use SilverStripe\PolyExecution\PolyOutput;
use SilverStripe\Versioned\Versioned;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use TractorCow\Fluent\State\FluentState;

/**
 * Applies a reviewed SEO/A11y content changeset (JSON) to the DRAFT stage. Never publishes.
 *
 * Each change carries the exact "before" value captured at audit time. If the current value differs,
 * the change is reported as a conflict and left untouched (content was edited after the audit).
 *
 * ddev exec vendor/bin/sake tasks:ywli-apply-changeset --file=/var/www/html/changeset.json --dry-run
 * ddev exec vendor/bin/sake tasks:ywli-apply-changeset --file=/var/www/html/changeset.json
 * ddev exec vendor/bin/sake tasks:ywli-apply-changeset --file=/var/www/html/changeset.json --rollback
 *
 * Changeset format:
 * {"meta":{...},"changes":[{"class":"Page","id":12,"locale":"de_DE","field":"MetaDescription",
 *   "before":"...","after":"...","finding":"CSEO-004"}]}
 */
class ApplySeoChangesetTask extends BuildTask
{
    protected static string $commandName = 'ywli-apply-changeset';

    protected string $title = 'YWLI: apply SEO/A11y content changeset (draft only)';

    protected static string $description = 'Writes reviewed field changes to the Draft stage. Never publishes.';

    /**
     * Fields this task may write. Extend per project via YAML:
     * App\Tasks\ApplySeoChangesetTask: { allowed_fields: [ ... ] }
     */
    private static array $allowed_fields = [
        'Title',
        'MenuTitle',
        'MetaDescription',
        'Content',
        'HTML',
        'AltText',
    ];

    public function getOptions(): array
    {
        return [
            new InputOption('file', null, InputOption::VALUE_REQUIRED, 'Absolute path to the changeset JSON'),
            new InputOption('rollback', null, InputOption::VALUE_NONE, 'Restore the "before" values'),
            new InputOption('dry-run', null, InputOption::VALUE_NONE, 'Report what would change, write nothing'),
        ];
    }

    protected function execute(InputInterface $input, PolyOutput $output): int
    {
        $file = (string) $input->getOption('file');
        if ($file === '' || !is_readable($file)) {
            $output->writeln("<error>Changeset not readable: {$file}</error>");
            return Command::FAILURE;
        }

        try {
            $set = json_decode((string) file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException $e) {
            $output->writeln('<error>Invalid JSON: ' . $e->getMessage() . '</error>');
            return Command::FAILURE;
        }

        $rollback = (bool) $input->getOption('rollback');
        $dryRun = (bool) $input->getOption('dry-run');
        $allowed = (array) static::config()->get('allowed_fields');
        $stats = ['applied' => 0, 'unchanged' => 0, 'skipped' => 0, 'conflict' => 0];

        Versioned::withVersionedMode(function () use ($set, $rollback, $dryRun, $allowed, $output, &$stats): void {
            Versioned::set_stage(Versioned::DRAFT);

            foreach ($set['changes'] ?? [] as $i => $change) {
                $apply = function () use ($i, $change, $rollback, $dryRun, $allowed, $output, &$stats): void {
                    $class = (string) ($change['class'] ?? '');
                    $id = (int) ($change['id'] ?? 0);
                    $field = (string) ($change['field'] ?? '');
                    $label = sprintf('#%d %s#%d.%s%s', $i, $class, $id, $field, isset($change['locale']) ? " [{$change['locale']}]" : '');

                    if (!in_array($field, $allowed, true) || !class_exists($class) || !is_a($class, DataObject::class, true)) {
                        $stats['skipped']++;
                        $output->writeln("skip     {$label} (class unknown or field not allowed)");
                        return;
                    }

                    $record = DataObject::get_by_id($class, $id);
                    if (!$record || !$record->hasField($field)) {
                        $stats['skipped']++;
                        $output->writeln("skip     {$label} (record or field not found)");
                        return;
                    }

                    [$expected, $new] = $rollback
                        ? [(string) $change['after'], (string) $change['before']]
                        : [(string) $change['before'], (string) $change['after']];
                    $current = (string) $record->getField($field);

                    if ($current === $new) {
                        $stats['unchanged']++;
                        return;
                    }
                    if ($current !== $expected) {
                        $stats['conflict']++;
                        $output->writeln("CONFLICT {$label} (changed since audit, left untouched)");
                        return;
                    }

                    if (!$dryRun) {
                        $record->setField($field, $new);
                        $record->write(); // Draft stage only. Publishing is done by a human in the CMS.
                    }
                    $stats['applied']++;
                    $output->writeln(($dryRun ? 'would    ' : 'applied  ') . $label);
                };

                if (!empty($change['locale']) && class_exists(FluentState::class)) {
                    FluentState::singleton()->withState(function (FluentState $state) use ($change, $apply): void {
                        $state->setLocale((string) $change['locale']);
                        $apply();
                    });
                } else {
                    $apply();
                }
            }
        });

        $output->writeln(sprintf(
            '%s applied=%d unchanged=%d skipped=%d conflict=%d',
            $dryRun ? '[dry-run]' : '[done]',
            $stats['applied'],
            $stats['unchanged'],
            $stats['skipped'],
            $stats['conflict']
        ));

        return $stats['conflict'] > 0 ? Command::FAILURE : Command::SUCCESS;
    }
}
