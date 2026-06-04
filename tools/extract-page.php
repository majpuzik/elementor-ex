<?php
/**
 * Extraktor Elementor _elementor_data → nativní post_content (Gutenberg bloky).
 * Použití: wp eval-file cr-extract.php <post_id> [--apply]
 * Bez --apply jen vypíše složený obsah (dry-run).
 */
$args = $GLOBALS['argv'] ?? array();
// wp eval-file předává poziční args; vezmi je z $args po názvu skriptu
$pos = array(); foreach ($args as $a) { if ($a==='--apply') { $APPLY=true; continue; } if (is_numeric($a)) $pos[]=(int)$a; }
$APPLY = $APPLY ?? false;
$post_id = $pos[0] ?? 0;
if (!$post_id) { fwrite(STDERR,"chybí post_id\n"); return; }

$data = get_post_meta($post_id, '_elementor_data', true);
$json = is_string($data) ? json_decode($data, true) : $data;
if (!is_array($json)) { fwrite(STDERR,"#$post_id: žádná _elementor_data\n"); return; }

$blocks = array();
$walk = function($els) use (&$walk, &$blocks) {
    foreach ((array)$els as $el) {
        $wt = $el['widgetType'] ?? ($el['settings']['widgetType'] ?? null);
        $s  = $el['settings'] ?? array();
        if ($wt === 'html') {
            $html = trim((string)($s['html'] ?? ''));
            if ($html !== '') $blocks[] = "<!-- wp:html -->\n".$html."\n<!-- /wp:html -->";
        } elseif ($wt === 'shortcode') {
            $sc = trim((string)($s['shortcode'] ?? ''));
            if ($sc !== '') $blocks[] = "<!-- wp:shortcode -->".$sc."<!-- /wp:shortcode -->";
        } elseif ($wt === 'text-editor') {
            $ed = trim((string)($s['editor'] ?? ''));
            if ($ed !== '') $blocks[] = "<!-- wp:html -->\n".$ed."\n<!-- /wp:html -->";
        }
        if (!empty($el['elements'])) $walk($el['elements']);
    }
};
$walk($json);
$content = implode("\n\n", $blocks);

if ($APPLY) {
    wp_update_post(array('ID'=>$post_id, 'post_content'=>$content));
    echo "#$post_id APPLIED: ".count($blocks)." bloků, ".strlen($content)."B\n";
} else {
    echo "=== #$post_id DRY-RUN: ".count($blocks)." bloků, ".strlen($content)."B ===\n";
    echo mb_substr($content, 0, 600)."\n...\n";
}
