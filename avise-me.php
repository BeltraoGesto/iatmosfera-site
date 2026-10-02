<?php
/**
 * iAtmosfera — "Avise-me quando lançar"
 *
 * Recebe o e-mail do formulário da página (POST, JSON ou form-data), guarda em
 * dados/avise-me.csv (pasta protegida por .htaccess) e envia um aviso para a
 * equipe. Se este arquivo não estiver publicado ou o PHP falhar, a página cai
 * sozinha no fallback (abre o e-mail do visitante com mailto:).
 *
 * Ajustes: mude DESTINO (quem recebe os avisos) e REMETENTE (endereço do domínio).
 */
declare(strict_types=1);

const DESTINO   = 'contato@iatmosfera.com.br';
const REMETENTE = 'no-reply@iatmosfera.com.br';
const ARQUIVO   = __DIR__ . '/dados/avise-me.csv';

ini_set('display_errors', '0'); // a resposta é JSON; qualquer aviso vai só para o log
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

$email = strtolower($campo('email'));
$nome  = $campo('nome');
$erp   = $campo('erp');
$pote  = $campo('site'); // honeypot: humanos deixam vazio

if ($pote !== '') { // robô preencheu o campo escondido: finge sucesso e ignora
    echo json_encode(['ok' => true]);
    exit;
}
if (mb_strlen($email) > 160 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(422);
    echo json_encode(['ok' => false, 'erro' => 'email']);
    exit;
}
$nome = mb_substr($nome, 0, 120);
$erp  = mb_substr($erp, 0, 60);

// célula que começa com = + - @ ou tabulação viraria fórmula na planilha: neutraliza
$neutraliza = static function (string $v): string {
    return ($v !== '' && strpbrk($v[0], "=+-@\t\r") !== false) ? "'" . $v : $v;
};

// grava (uma linha por pedido) — a pasta dados/ é bloqueada para o navegador
$linha = [date('c'), $neutraliza($email), $neutraliza($nome), $neutraliza($erp), $_SERVER['REMOTE_ADDR'] ?? ''];
$dir = dirname(ARQUIVO);
if (!is_dir($dir)) { @mkdir($dir, 0755, true); }
$fh = @fopen(ARQUIVO, 'a');
$gravou = false;
if ($fh) {
    if (flock($fh, LOCK_EX)) {
        $st = fstat($fh);
        if ($st === false || $st['size'] === 0) {
            fputcsv($fh, ['quando', 'email', 'nome', 'erp', 'ip'], ',', '"', '');
        }
        $gravou = fputcsv($fh, $linha, ',', '"', '') !== false;
        flock($fh, LOCK_UN);
    }
    fclose($fh);
}

// avisa a equipe (não bloqueia a resposta se o mail() não estiver disponível)
$assunto = '=?UTF-8?B?' . base64_encode('iAtmosfera — novo interessado: ' . $email) . '?=';
$corpo = "Novo pedido de aviso de lançamento\n\n"
       . "E-mail: {$email}\n"
       . ($nome !== '' ? "Nome: {$nome}\n" : '')
       . ($erp !== '' ? "Sistema: {$erp}\n" : '')
       . "Quando: " . date('d/m/Y H:i') . "\n";
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
