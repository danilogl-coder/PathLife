@tool
class_name HairDefinition
extends Resource
## UM penteado. E' o que o HairManager recebe em equip_hair().
##
## O que nao esta aqui: nenhuma regra. A definicao aponta para os dados
## (gerados) e para os perfis (autorais), e o resto do sistema le' isso. Nao
## existe em lugar nenhum um 'if penteado == "rabo_alto"'; um penteado novo e'
## um .tres novo, sem uma linha de codigo.

## Chave do penteado dentro do JSON. Ex.: "rabo_alto", "basico_pe".
@export var estilo: StringName = &""

## JSON gerado por gerar_cabelo_fisica.py. Traz, por direcao: as pecas base
## (frente e tras), as cadeias, os segmentos de cada cadeia, os pivos e o z.
@export_file("*.json") var dados: String = ""

## Raiz das texturas que o JSON referencia (os caminhos do JSON sao relativos).
@export_dir var pasta_texturas: String = ""

@export_group("Fisica")
## Perfil usado por qualquer cadeia que nao tenha um proprio.
@export var perfil_padrao: HairPhysicsProfile
## Perfil por cadeia, pelo nome que o JSON declara ("rabo", "mecha_esq", ...).
## Um twintail e' o mesmo perfil nas duas cadeias; ja' um penteado com rabo e
## franja quer perfis diferentes, e e' so' preencher aqui.
@export var perfil_por_cadeia: Dictionary[StringName, HairPhysicsProfile] = {}

@export_group("Ajuste fino")
## Deslocamento em px aplicado as duas pecas, se o penteado precisar assentar.
@export var deslocamento: Vector2 = Vector2.ZERO
## Multiplica o limite de rotacao de todas as cadeias. Serve para amansar um
## penteado especifico sem clonar o perfil inteiro.
@export_range(0.0, 2.0, 0.05) var escala_limite: float = 1.0


func perfil_de(cadeia: StringName) -> HairPhysicsProfile:
	var p: HairPhysicsProfile = perfil_por_cadeia.get(cadeia)
	return p if p != null else perfil_padrao
