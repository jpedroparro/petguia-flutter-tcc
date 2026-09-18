/**
 * Módulo de Gestão de Dados e Conhecimento — modelos de domínio persistidos
 * no Firestore. Ver README.md desta pasta para a citação do TCC.
 */

export type AnimalStatus =
  | "resgatado"
  | "em_abrigo"
  | "com_tutor"
  | "reunificado";
export type AnimalPorte = "pequeno" | "medio" | "grande";

export interface Animal {
  id: string;
  especie: string;
  raca: string;
  porte: AnimalPorte;
  estadoSaude: string;
  localizacaoResgate: string;
  cepResgate: string | null;
  latitudeResgate: number | null;
  longitudeResgate: number | null;
  comColeira: boolean;
  nomeIdentificacao: string | null;
  telefoneContato: string | null;
  fotoUrl: string | null;
  abrigoId: string | null;
  status: AnimalStatus;
  registradoPor: string;
  criadoEm: string;
}

export interface Abrigo {
  id: string;
  nome: string;
  endereco: string;
  cep: string;
  telefone: string;
  capacidadeTotal: number;
  capacidadeOcupada: number;
  latitude: number | null;
  longitude: number | null;
  ativo: boolean;
  criadoEm: string;
}

export type StatusSolicitacao = "pendente" | "confirmada" | "recusada";

export type StatusResgate = "pendente" | "em_atendimento" | "concluido";

/**
 * Alerta de resgate urgente — situação em que o animal não pode ser
 * simplesmente buscado a pé (preso em árvore, telhado, ilhado pela
 * enchente), reportada pelo público e vista pela equipe (Defesa
 * Civil/bombeiros) como um alerta a atender.
 */
export interface SolicitacaoResgate {
  id: string;
  descricaoSituacao: string;
  rua: string;
  bairro: string;
  latitude: number | null;
  longitude: number | null;
  nomeContato: string;
  telefoneContato: string;
  fotoUrl: string | null;
  status: StatusResgate;
  criadoEm: string;
}

export interface SolicitacaoReunificacao {
  id: string;
  animalId: string;
  nomeTutor: string;
  telefoneTutor: string;
  mensagem: string | null;
  status: StatusSolicitacao;
  criadoEm: string;
}

export interface SolicitacaoTutoria {
  id: string;
  animalId: string;
  nomeTutor: string;
  dataNascimentoTutor: string;
  cpfTutor: string;
  telefoneTutor: string;
  status: StatusSolicitacao;
  criadoEm: string;
}

export interface RuaCota {
  id: string;
  nome: string;
  cotaMinima: number;
  cotaMaxima: number | null;
  /** Verdadeiro quando `cotaMaxima` é estimativa nossa (cotaMinima + margem,
   * limitada ao recorde histórico), não dado oficial da Defesa Civil — só a
   * cota mínima tem fonte oficial pra essas ruas. */
  cotaMaximaEstimada?: boolean;
  latitude: number | null;
  longitude: number | null;
}

export type ClassificacaoRio = "normal" | "atencao" | "alerta" | "emergencia";

export interface LeituraRio {
  id: string;
  nivel: number;
  fonte: string;
  coletadoEm: string;
}
