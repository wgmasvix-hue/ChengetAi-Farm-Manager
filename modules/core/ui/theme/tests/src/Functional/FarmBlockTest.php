<?php

declare(strict_types=1);

namespace Drupal\Tests\farm_ui_theme\Functional;

use Drupal\Tests\farm_test\Functional\FarmBrowserTestBase;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Tests the "Powered by ChengetAi Farm Manager" block.
 */
#[Group('farm')]
#[RunTestsInSeparateProcesses]
class FarmBlockTest extends FarmBrowserTestBase {

  /**
   * {@inheritdoc}
   */
  protected static $modules = [
    'farm_ui_theme',
  ];

  /**
   * Test that the "Powered by ChengetAi Farm Manager" block is visible.
   */
  public function testFarmBlock() {
    $this->assertSession()->pageTextContains('Powered by ChengetAi Farm Manager');
  }

}
