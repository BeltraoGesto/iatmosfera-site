<?php
/**
 * iAtmosfera — formulário "Contato" da landing page
 *
 * Recebe nome, e-mail e mensagem (POST, JSON ou form-data), guarda em
 * dados/contato.csv (pasta protegida por .htaccess) e envia para a equipe.
 * Se este arquivo não estiver publicado ou o PHP falhar, a página cai sozinha
 * no fallback (abre o e-mail do visitante com mailto:).
 *
 * Ajustes: mude DESTINO (quem recebe) e REMETENTE (endereço do domínio).
 */
declare(strict_types=1);

const DESTINO   = 'contato@iatmosfera.com.br';
const REMETENTE = 'no-reply@iatmosfera.com.br';
const ARQUIVO   = __DIR__ . '/dados/contato.csv';

ini_set('display_errors', '0');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'erro' => 'metodo']);
    exit;
}

$bruto = file_get_contents('php://input') ?: '';
$dados = json_decode($bruto, true);
if (!is_array($dados)) {
    $dados = $_POST;
}
$campo = static fn(string $k): string => is_scalar($dados[$k] ?? null) ? trim((string)$dados[$k]) : '';

$nome     = $campo('nome');
$email    = strtolower($campo('email'));
$mensagem = $campo('mensagem');
$pote     = $campo('site'); // honeypot

if ($pote !== '') {
    echo json_encode(['ok' => true]);
    exit;
}
if ($nome === '' || mb_strlen($nome) > 120
    || mb_strlen($email) > 160 || !filter_var($email, FILTER_VALIDATE_EMAIL)
    || mb_strlen($mensagem) < 5 || mb_strlen($mensagem) > 2000) {
    http_response_code(422);
    echo json_encode(['ok' => false, 'erro' => 'campos']);
    exit;
}
// nome e e-mail entram em cabeçalhos: nada de quebras de linha
$nome  = preg_replace('/[\r\n]+/', ' ', $nome);
$email = preg_replace('/[\r\n]+/', '', $email);

$neutraliza = static function (string $v): string {
    return ($v !== '' && strpbrk($v[0], "=+-@\t\r") !== false) ? "'" . $v : $v;
};

$linha = [date('c'), $neutraliza($nome), $neutraliza($email), $neutraliza($mensagem), $_SERVER['REMOTE_ADDR'] ?? ''];
$dir = dirname(ARQUIVO);
if (!is_dir($dir)) { @mkdir($dir, 0755, true); }
$fh = @fopen(ARQUIVO, 'a');
$gravou = false;
if ($fh) {
    if (flock($fh, LOCK_EX)) {
        $st = fstat($fh);
        if ($st === false || $st['size'] === 0) {
            fputcsv($fh, ['quando', 'nome', 'email', 'mensagem', 'ip'], ',', '"', '');
        }
        $gravou = fputcsv($fh, $linha, ',', '"', '') !== false;
        flock($fh, LOCK_UN);
    }
    fclose($fh);
}

$assunto = '=?UTF-8?B?' . base64_encode('iAtmosfera — contato: ' . $nome) . '?=';
$corpo = "Nova mensagem pelo site\n\n"
       . "Nome: {$nome}\n"
       . "E-mail: {$email}\n"
       . "Quando: " . date('d/m/Y H:i') . "\n\n"
       . $mensagem . "\n";
$cabecalhos = "From: iAtmosfera <" . REMETENTE . ">\r\n"
            . "Reply-To: {$email}\r\n"
            . "Content-Type: text/plain; charset=UTF-8\r\n";
$enviou = @mail(DESTINO, $assunto, $corpo, $cabecalhos);

if (!$gravou && !$enviou) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'erro' => 'servidor']);
    exit;
}
echo json_encode(['ok' => true]);
