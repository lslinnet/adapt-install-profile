<?php

/**
 * Implements hook_menu().
 */
function adapt_install_profile_menu() {
  $items = array();

  $items['admin/adapt-install-profile-settings'] = array(
    'title' => 'Adapt Install Profile settings',
    'description' => 'Adapt Install Profile settings',
    'page callback' => 'drupal_get_form',
    // This page should only be available for the super user
    'page arguments' => array('adapt_install_profile_settings_form'),
    'access callback' => 'access content', // TODO: Set
    'type' => MENU_CALLBACK,
    );

  return $items;
}

/**
 * Implements hook_form().
 * This is the Basic Settings form
 */
function adapt_install_profile_settings_form($node, &$form_state) {
  // Build the languages array.
  // The default language object is stored in the language_default variable.
  $langs = drupal_map_assoc(array(
    'da',
    'en'
    ));
  $default_language = variable_get('language_default', (object) array('language' => 'da'));
  $enabled_languages = @array_keys(reset(language_list('enabled')));

  // Build the form.
  $form = array();

  $form['languages'] = array(
    '#type' => 'fieldset',
    '#title' => t('Languages'),
    '#collapsible' => FALSE,
    );

  $form['languages']['active_languages'] = array(
    '#type' => 'checkboxes',
    '#title' => t('Which languages would you like to enable?'),
    '#options' => array_diff($langs, $enabled_languages),
    '#description' => t('<strong>Enabled language(s):</strong><br />@langs<br /><br /><strong>Default language:</strong><br />@def_lang', array(
      '@langs' => implode(', ', $enabled_languages),
      '@def_lang' => $default_language->language,
      )),
    );

  return $form;
}

/**
 * Form submit handler for Basic Settings form.
 */
function adapt_install_profile_settings_form_submit($node, &$form_state) {
  // Handle the languages section
  _adapt_install_profile_settings_language_submit_handler($form_state['values']['active_languages']);

  // More stuff to follow

  $form_state['redirect'] = '';

  // clear all caches after settings completion
  cache_clear_all();
}

/**
 *
 */
function _adapt_install_profile_settings_language_submit_handler($languages) {
  // Language counter is used to define if i18n needs to be enabled
  // and to set the language_count variable.
  $enabled_count = 1;
  foreach ($languages as $langcode => $name) {
    if ($name !== 0) {
      // Enable the language
      if (!array_key_exists($langcode, language_list())) {
        locale_add_language($langcode);
      } else {
        // Update an existing language, can be done with a simple query
        // @see locale_languages_overview_form_submit
        db_update('languages')
        ->fields(array(
          'enabled' => 1,
          ))
        ->condition('language', $langcode)
        ->execute();
      }
      // And update the language counter
      $enabled_count++;
    }
  }

  variable_set('language_count', $enabled_count);
  // Changing the language settings impacts the interface.
  cache_clear_all();
  module_invoke_all('multilingual_settings_changed');
}

/**
 * Implements hook_install_tasks_alter()
 */
function adapt_install_profile_install_tasks_alter(&$tasks, $install_state) {
  // Overwrite this with our own function where we'll add stuff.
  $tasks['install_finished']['function'] = '_adapt_install_profile_install_finished';
}

/**
 * hook_install_tasks_alter() callback
 *
 * Execute finish tasks and redirect to settings form
 * Most stuff is copied from https://api.drupal.org/api/drupal/includes%21install.core.inc/function/install_finished/7
 */
function _adapt_install_profile_install_finished(&$install_state) {
  drupal_set_title(st('@drupal installation complete', array('@drupal' => drupal_install_profile_distribution_name())), PASS_THROUGH);
  $messages = drupal_set_message();
  $output = '<p>' . st('Congratulations, you installed @drupal!', array('@drupal' => drupal_install_profile_distribution_name())) . '</p>';

  if (isset($messages['error'])) {
    $output .= "<p>" . st('Review the messages above before visiting <a href="@url">your new site</a>.', array('@url' => url(''))) . "</p>";
  } else {
    $output .= "<p>" . st('<a href="@url">Visit your new site</a>.', array('@url' => url(''))) . "</p>";
    $output .= "<p>" . st('<a href="@url">Go to the settings page</a>.', array('@url' => url('admin/adapt-install-profile-settings'))) . "</p>";
  }

  // Flush all caches to ensure that any full bootstraps during the installer
  // do not leave stale cached data, and that any content types or other items
  // registered by the installation profile are registered correctly.
  drupal_flush_all_caches();

  // Remember the profile which was used.
  variable_set('install_profile', drupal_get_profile());

  // Installation profiles are always loaded last
  db_update('system')->fields(array('weight' => 1000))->condition('type', 'module')->condition('name', drupal_get_profile())->execute();

  // Cache a fully-built schema.
  drupal_get_schema(NULL, TRUE);

  // Run cron to populate update status tables (if available) so that users
  // will be warned if they've installed an out of date Drupal version.
  // Will also trigger indexing of profile-supplied content or feeds.
  drupal_cron_run();

  return $output;
}
