#!/bin/bash
DBNAME=importar
DBUSER=root
DBPASS=123456
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

# Nome do arquivo a importar sempre deverá ser dados_excel.csv
# criar par de chaves ssh para acesso ao git 

echo "${red}limpando tabela com resultados antigos...${reset}"

mysql -u $DBUSER -p$DBPASS $DBNAME -e "TRUNCATE TABLE importar_csv;"

echo "${green}importando arquivo CSV...${reset}"

mysql -u $DBUSER -p$DBPASS <<EOFMYSQL
use $DBNAME;
LOAD DATA LOCAL INFILE '/home/ec2-user/evolve/importacsv/dados_excel.csv'
    INTO TABLE importar_csv
    FIELDS TERMINATED BY ';'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (   ID,
        SEQ,
        ID2,
        Num_Servico,
        Km_Servico,
        Preco_Fixo,
        Ano_Veiculo,
        Modelo_Veiculo,
        Versao_Veiculo,
        Tipo_Veiculo,
        Tipo_Peca,
        Cod_Peca,
        Desc_Peca,
        Qtde_Peca,
        Preco_Peca,
        Preco_Total,
        Tempo_Padrao_Reparo,
        Tempo_Adicional_Reparo,
        UTC_Reparo,
        Regiao_Mao_Obra,
        Tempo_Mao_Obra,
        Preco_Mao_Obra,
        TOTAL_GERAL);
EOFMYSQL

echo "${green}Arquivo CSV importado com sucesso...${reset}"

CONTA=$(mysql -u $DBUSER -p$DBPASS $DBNAME -se "SELECT COUNT(*) FROM importar_csv")
echo "$CONTA Linhas inseridas"


echo "${red}Excluindo linhas que não pertencem a região 3...${reset}"
mysql -u $DBUSER -p$DBPASS $DBNAME -e "DELETE FROM importar_csv WHERE Regiao_Mao_Obra <> 3;"

CONTA_RESTANTE=$(mysql -u $DBUSER -p$DBPASS $DBNAME -se "SELECT COUNT(*) FROM importar_csv")
echo "$CONTA_RESTANTE Linhas restantes."

echo "${green}Criando tabela temporária de agrupamento...${reset}";
mysql -u $DBUSER -p$DBPASS <<EOFMYSQL
use $DBNAME;
CREATE TABLE tmp_soma
        select ID as id_veiculo,
               Modelo_Veiculo as modelo,
               Versao_Veiculo as versao,
               Ano_Veiculo as ano,
               Num_Servico as num_servico,
               (select sum(TOTAL_GERAL)
                    from importar_csv where ID = id_veiculo) as soma
        from importar_csv
        group by ID
        order by Modelo_Veiculo, Versao_Veiculo, Num_Servico;
EOFMYSQL

echo "${red}Excluindo tabela de filtro caso exista...${reset}";
mysql -u $DBUSER -p$DBPASS $DBNAME -e "DROP TABLE IF EXISTS tmp_filtro;"
echo "${green}Tabela de filtro excluída.${reset}";

echo "${green}Criando tabela de filtros com todos os anos...${reset}";
mysql -u $DBUSER -p$DBPASS <<EOFMYSQL
use $DBNAME
CREATE TABLE tmp_filtro
        SELECT s.modelo, s.versao, ano,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 1) as servico_1,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 2) as servico_2,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 3) as servico_3,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 4) as servico_4,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 5) as servico_5,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 6) as servico_6,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 7) as servico_7,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 8) as servico_8,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 9) as servico_9,
            (SELECT soma from tmp_soma WHERE modelo = s.modelo AND versao = s.versao AND ano = s.ano AND num_servico = 10) as servico_10

            FROM tmp_soma as s
        GROUP BY s.modelo, s.versao, s.ano;
EOFMYSQL

$CONTA_FILTRO=$(mysql -u $DBUSER -p$DBPASS $DBNAME -se "SELECT COUNT(*) FROM tmp_filtro;")
echo "$CONTA_FILTRO Linhas filtradas."

echo "${red}Excluindo tabela de agrupamento...${reset}"
mysql -u $DBUSER -p$DBPASS $DBNAME -e "DROP TABLE tmp_soma;"
echo "${green}Tabela de agrupamento excluída.${reset}";

echo "${red}Excluindo tabela final caso ela exista...${reset}"
mysql -u $DBUSER -p$DBPASS $DBNAME -e "DROP TABLE ID EXISTS filtro_manutencao;"
echo "${green}Tabela final excluída.${reset}";


echo "${green}Preparando resultado final...${reset}";
mysql -u $DBUSER -p$DBPASS <<EOFMYSQL
use $DBNAME
CREATE TABLE filtro_manutencao
select f.modelo, f.versao,
       (select min(ano) from tmp_filtro
           where modelo = f.modelo
           and tmp_filtro.versao = f.versao
           and tmp_filtro.servico_1 = f.servico_1
           and tmp_filtro.servico_2 = f.servico_2
           and tmp_filtro.servico_3 = f.servico_3
           and tmp_filtro.servico_4 = f.servico_4
           and tmp_filtro.servico_5 = f.servico_5
           and tmp_filtro.servico_6 = f.servico_6
           and tmp_filtro.servico_7 = f.servico_7
           and tmp_filtro.servico_8 = f.servico_8
           and tmp_filtro.servico_9 = f.servico_9
           and tmp_filtro.servico_10 = f.servico_10
           ) as ano_inicio,
       (select max(ano) from tmp_filtro
           where modelo = f.modelo
           and tmp_filtro.versao = f.versao
           and tmp_filtro.servico_1 = f.servico_1
           and tmp_filtro.servico_2 = f.servico_2
           and tmp_filtro.servico_3 = f.servico_3
           and tmp_filtro.servico_4 = f.servico_4
           and tmp_filtro.servico_5 = f.servico_5
           and tmp_filtro.servico_6 = f.servico_6
           and tmp_filtro.servico_7 = f.servico_7
           and tmp_filtro.servico_8 = f.servico_8
           and tmp_filtro.servico_9 = f.servico_9
           and tmp_filtro.servico_10 = f.servico_10
           ) as ano_fim,
       f.servico_1,
       f.servico_2,
       f.servico_3,
       f.servico_4,
       f.servico_5,
       f.servico_6,
       f.servico_7,
       f.servico_8,
       f.servico_9,
       f.servico_10

from tmp_filtro f

group by modelo, versao, servico_1, servico_2, servico_3, servico_4, servico_5, servico_6, servico_7, servico_8, servico_9, servico_10;
EOFMYSQL

CONTA_FINAL=$(mysql -u $DBUSER -p$DBPASS $DBNAME -se "SELECT COUNT(*) FROM filtro_manutencao")
echo "$CONTA_FINAL Linhas inseridas."


echo "${red}Excluindo primeira tabela de filtro...${reset}";
mysql -u $DBUSER -p$DBPASS $DBNAME -e "DROP TABLE IF EXISTS tmp_filtro"
echo "${green}Primeira tabela de filtro excluída...${reset}";

#echo "${green}Consultando resultado final...${reset}";
#mysql -u $DBUSER -p$DBPASS $DBNAME -e "SELECT * FROM filtro_manutencao"

PATH_CSV="/home/ec2-user/evolve/importacsv/csv"
FILE_CSV="$PATH_CSV/relatorio.csv"
if [ ! -d "$PATH_CSV" ];
then
echo "Criando pasta para exportação..."
mkdir "$PATH_CSV"
cd "$PATH_CSV"
echo "Clonando repositório GIT..."
git clone git@github.com:mobcubestudio/expcsv.git .
fi

cd "$PATH_CSV"
echo "Excluindo ultimo arquivo CSV exportado..."
rm "$FILE_CSV"

git add .
git commit -m "Excluindo arquivo"
git push

CABECALHO_CSV="MODELO;VERSAO;ANO INICIO;ANO FIM;SERVICO 1;SERVICO 2;SERVICO 3;SERVICO 4;SERVICO 5;SERVICO 6;SERVICO 7;SERVICO 8;SERVICO 9;SERVICO 10\n"

echo "${green}Consultando resultados...${reset}"
RESULTADO=$(mysql -u $DBUSER -p$DBPASS $DBNAME -se "SELECT CONCAT(modelo,';',versao,';',ano_inicio,';',ano_fim,';',servico_1,';',servico_2,';',servico_3,';',servico_4,';',servico_5,';',servico_6,';',servico_7,';',servico_8,';',servico_9,';',servico_10,'\n') as col from filtro_manutencao")
echo "Exportando dados obtidos para arquivo CSV..."
echo -e $CABECALHO_CSV$RESULTADO > $FILE_CSV
echo "${green}Arquivo relatorio.csv criado com sucesso.${reset}"

echo "${yellow}<<<<<<<<<<<<<<<< GIT >>>>>>>>>>>>>>>>>>>>${reset}"
git add .
git commit -m "Enviando arquivo de relatório"
git push
