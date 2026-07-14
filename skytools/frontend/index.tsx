import {
	DialogButton,
	Field,
	IconsModule,
	definePlugin,
	callable,
} from '@steambrew/client';
import { useEffect, useMemo, useState } from 'react';

type SkyResult<T> = {
	success: boolean;
	data?: T;
	error?: string;
};

type Status = {
	steamPath: string;
	scriptDirectory: string;
	dataPath: string;
	integration: string;
	configuredIntegration: string;
	installedCount: number;
	preferredApi: string;
	hasMorrenusKey: boolean;
};

type InstalledGame = {
	appId: number;
	gameName: string;
	fileName: string;
	fullPath: string;
	isDisabled: boolean;
	isSteamInstalled: boolean;
	hasAppliedFix: boolean;
	imageUrl: string;
};

type ManifestApi = {
	id: string;
	name: string;
	urlTemplate: string;
	apiKey: string;
	useProxy: boolean;
	proxyUrlTemplate: string;
	successCode: number;
	unavailableCode: number;
	enabled: boolean;
};

type ApiList = {
	preferred: string;
	builtIn: Array<{ id: string; name: string; editable: boolean; requiresKey?: boolean }>;
	custom: ManifestApi[];
};

type FixSource = {
	name: string;
	type: string;
	downloadUrl: string;
	size: string;
	provider: string;
};

type FixLookup = {
	gamePath: string;
	sources: FixSource[];
};

type ExternalFixResult = {
	title: string;
	provider?: string;
	source?: string;
	details?: string;
	url?: string;
	sourceUrl?: string;
	downloadUrl?: string;
	fixSource?: FixSource;
};

const statusRaw = callable<[], string>('skytools_status');
const installedRaw = callable<[], string>('skytools_installed');
const removeGameRaw = callable<[{ appid: number; name: string }], string>('skytools_remove_game');
const apisRaw = callable<[], string>('skytools_apis');
const saveApiRaw = callable<[Record<string, string | number | boolean>], string>('skytools_save_api');
const deleteApiRaw = callable<[{ id: string }], string>('skytools_delete_api');
const backupExportRaw = callable<[{ path: string }], string>('skytools_backup_export');
const fixSourcesRaw = callable<[{ appid: number; name: string }], string>('skytools_fix_sources');
const applyFixRaw = callable<[{ appid: number; name: string; gamePath: string; sourceJson: string }], string>('skytools_apply_fix');
const onlineFixRaw = callable<[{ appid: number; name: string }], string>('skytools_online_fix');
const denuvoFixRaw = callable<[{ appid: number; name: string }], string>('skytools_denuvo_fix');
const repairRaw = callable<[{ repair: string; appid?: number }], string>('skytools_repair');
const integrationRaw = callable<[{ target: string }], string>('skytools_integration');

async function parseCall<T>(call: Promise<string>): Promise<SkyResult<T>> {
	const response = await call;
	if (typeof response !== 'string') {
		return response as SkyResult<T>;
	}
	try {
		return JSON.parse(response) as SkyResult<T>;
	} catch {
		return { success: false, error: response };
	}
}

const statusCall = () => parseCall<Status>(statusRaw());
const installedCall = () => parseCall<InstalledGame[]>(installedRaw());
const removeGameCall = (appid: number, name: string) => parseCall<unknown>(removeGameRaw({ appid, name }));
const apisCall = () => parseCall<ApiList>(apisRaw());
const saveApiCall = (api: ManifestApi) => parseCall<ManifestApi>(saveApiRaw(api as unknown as Record<string, string | number | boolean>));
const deleteApiCall = (id: string) => parseCall<unknown>(deleteApiRaw({ id }));
const backupExportCall = (path: string) => parseCall<{ path: string }>(backupExportRaw({ path }));
const fixSourcesCall = (appid: number, name: string) => parseCall<FixLookup>(fixSourcesRaw({ appid, name }));
const applyFixCall = (appid: number, name: string, gamePath: string, source: FixSource) =>
	parseCall<unknown>(applyFixRaw({ appid, name, gamePath, sourceJson: JSON.stringify(source) }));
const onlineFixCall = (appid: number, name: string) => parseCall<ExternalFixResult[]>(onlineFixRaw({ appid, name }));
const denuvoFixCall = (appid: number, name: string) => parseCall<ExternalFixResult[]>(denuvoFixRaw({ appid, name }));
const repairCall = (repair: string, appid?: number) => parseCall<unknown>(repairRaw({ repair, appid }));
const integrationCall = (target: string) => parseCall<unknown>(integrationRaw({ target }));

const emptyApi: ManifestApi = {
	id: '',
	name: '',
	urlTemplate: '',
	apiKey: '',
	useProxy: false,
	proxyUrlTemplate: '',
	successCode: 200,
	unavailableCode: 404,
	enabled: true,
};

function unwrap<T>(result: SkyResult<T>): T {
	if (!result.success) {
		throw new Error(result.error || 'Operacao falhou.');
	}
	return result.data as T;
}

function SkyToolsPanel() {
	const [tab, setTab] = useState('installed');
	const [status, setStatus] = useState<Status | null>(null);
	const [installed, setInstalled] = useState<InstalledGame[]>([]);
	const [apis, setApis] = useState<ApiList | null>(null);
	const [apiForm, setApiForm] = useState<ManifestApi>(emptyApi);
	const [busy, setBusy] = useState(false);
	const [message, setMessage] = useState('Pronto');

	const tabs = useMemo(
		() => [
			['installed', 'Jogos Instalados'],
			['apis', 'APIs'],
			['fixes', 'Correcoes'],
			['backup', 'Backup'],
			['steam', 'Steam'],
		],
		[],
	);

	async function refresh() {
		setStatus(unwrap(await statusCall()));
		setInstalled(unwrap(await installedCall()));
		setApis(unwrap(await apisCall()));
	}

	useEffect(() => {
		refresh().catch((error: Error) => setMessage(error.message));
	}, []);

	async function run(label: string, action: () => Promise<void>) {
		setBusy(true);
		setMessage(label);
		try {
			await action();
			await refresh();
			setMessage('Concluido.');
		} catch (error) {
			setMessage(error instanceof Error ? error.message : String(error));
		} finally {
			setBusy(false);
		}
	}

	async function saveApi() {
		await run('Salvando API', async () => {
			if (!apiForm.name.trim()) {
				throw new Error('Informe um nome para a API.');
			}
			if (!apiForm.urlTemplate.includes('<appid>')) {
				throw new Error('A URL da API precisa conter <appid>.');
			}
			unwrap(await saveApiCall(apiForm));
			setApiForm(emptyApi);
		});
	}

	return (
		<div className="skytools-root">
			<style>{styles}</style>
			<div className="skytools-header">
				<div>
					<h2>SkyTools Plugin</h2>
					<p>{status?.steamPath || 'Steam nao detectada'}</p>
				</div>
				<span>{message}</span>
			</div>

			<div className="skytools-tabs">
				{tabs.map(([id, label]) => (
					<button key={id} className={tab === id ? 'active' : ''} onClick={() => setTab(id)}>{label}</button>
				))}
			</div>

			{tab === 'installed' && (
				<section className="skytools-list">
					{installed.length === 0 && <p className="skytools-empty">Nenhum script Lua encontrado na pasta ativa da Steam.</p>}
					{installed.map((game) => (
						<div className="skytools-game" key={game.appId}>
							<img src={game.imageUrl} />
							<div>
								<strong>{game.gameName || `AppID ${game.appId}`}</strong>
								<small>{game.fileName} {game.hasAppliedFix ? 'Fix aplicado' : ''}</small>
							</div>
							<button disabled={busy} onClick={() => run('Removendo jogo', async () => {
								unwrap(await removeGameCall(game.appId, game.gameName));
							})}>
								Remover
							</button>
						</div>
					))}
				</section>
			)}

			{tab === 'apis' && (
				<section>
					<div className="skytools-grid">
						<input value={apiForm.name} onChange={(event) => setApiForm({ ...apiForm, name: event.currentTarget.value })} placeholder="Nome da API" />
						<input value={apiForm.urlTemplate} onChange={(event) => setApiForm({ ...apiForm, urlTemplate: event.currentTarget.value })} placeholder="URL com <appid>" />
						<input value={apiForm.apiKey} onChange={(event) => setApiForm({ ...apiForm, apiKey: event.currentTarget.value })} placeholder="API key opcional" />
						<button disabled={busy || !apiForm.name.trim() || !apiForm.urlTemplate.includes('<appid>')} onClick={saveApi}>Salvar API</button>
					</div>
					<div className="skytools-list">
						{apis?.builtIn.map((api) => <div className="skytools-line" key={api.id}><span>{api.name}</span><small>Nativa</small></div>)}
						{apis?.custom.map((api) => (
							<div className="skytools-line" key={api.id}>
								<span>{api.name}</span>
								<button onClick={() => setApiForm(api)}>Editar</button>
								<button disabled={busy} onClick={() => run('Removendo API', async () => {
									unwrap(await deleteApiCall(api.id));
								})}>Excluir</button>
							</div>
						))}
					</div>
				</section>
			)}

			{tab === 'fixes' && (
				<section className="skytools-list">
					{installed.length === 0 && <p className="skytools-empty">Adicione um jogo primeiro para consultar correcoes relacionadas.</p>}
					{installed.map((game) => (
						<FixRow key={game.appId} game={game} busy={busy} run={run} />
					))}
				</section>
			)}

			{tab === 'backup' && (
				<section className="skytools-actions">
					<button disabled={busy} onClick={() => run('Criando backup', async () => {
						const result = unwrap(await backupExportCall(''));
						setMessage(`Backup salvo em ${result.path}`);
					})}>Criar backup compativel</button>
					<p>O arquivo pode ser lido pelo DolinTools e pelo SkyTools.</p>
				</section>
			)}

			{tab === 'steam' && (
				<section className="skytools-actions">
					<button disabled={busy} onClick={() => run('Ativando SkyTools', async () => {
						unwrap(await integrationCall('SkyTools'));
					})}>Usar pasta SkyTools</button>
					<button disabled={busy} onClick={() => run('Corrigindo cache', async () => {
						unwrap(await repairCall('error54'));
					})}>Limpar cache Erro 54</button>
					<button disabled={busy} onClick={() => run('Configurando DNS', async () => {
						unwrap(await repairCall('dns'));
					})}>DNS Cloudflare</button>
					<button disabled={busy} onClick={() => run('Instalando runtimes', async () => {
						unwrap(await repairCall('vcredist'));
					})}>Visual C++ Runtimes</button>
				</section>
			)}
		</div>
	);
}

function FixRow({ game, busy, run }: { game: InstalledGame; busy: boolean; run: (label: string, action: () => Promise<void>) => Promise<void> }) {
	const [sources, setSources] = useState<FixSource[]>([]);
	const [external, setExternal] = useState<ExternalFixResult[]>([]);
	const [gamePath, setGamePath] = useState('');

	async function load(type: 'normal' | 'online' | 'denuvo') {
		await run('Buscando correcoes', async () => {
			setSources([]);
			setExternal([]);
			if (type === 'normal') {
				const data = unwrap(await fixSourcesCall(game.appId, game.gameName));
				setGamePath(data.gamePath);
				setSources(data.sources);
			} else if (type === 'online') {
				setExternal(unwrap(await onlineFixCall(game.appId, game.gameName)));
			} else {
				const data = unwrap(await denuvoFixCall(game.appId, game.gameName));
				setSources(data.map((item) => item.fixSource).filter((item): item is FixSource => Boolean(item)));
				setExternal(data.filter((item) => !item.fixSource));
			}
		});
	}

	return (
		<div className="skytools-fix">
			<div className="skytools-line">
				<span>{game.gameName || `AppID ${game.appId}`}</span>
				<button disabled={busy} onClick={() => load('normal')}>Correcoes</button>
				<button disabled={busy} onClick={() => load('online')}>Online</button>
				<button disabled={busy} onClick={() => load('denuvo')}>Denuvo</button>
			</div>
			{sources.map((source) => (
				<div className="skytools-line" key={`${source.provider}-${source.name}-${source.downloadUrl}`}>
					<small>{source.name} {source.size}</small>
					<button disabled={busy || !gamePath} onClick={() => run('Aplicando correcao', async () => {
						unwrap(await applyFixCall(game.appId, game.gameName, gamePath, source));
					})}>
						Aplicar
					</button>
				</div>
			))}
			{external.map((item) => {
				const url = item.url || item.sourceUrl || item.downloadUrl || '';
				return (
					<div className="skytools-line" key={`${item.title}-${url}`}>
						<small>{item.title} {item.provider || item.source || ''}</small>
						<button disabled={!url} onClick={() => window.open(url, '_blank')}>Abrir</button>
					</div>
				);
			})}
			{sources.length === 0 && external.length === 0 && (
				<p className="skytools-empty">Nenhuma correcao carregada ainda.</p>
			)}
		</div>
	);
}

function SettingsContent() {
	return (
		<>
			<Field label="SkyTools Plugin" description="DolinTools dentro da Steam." icon={<IconsModule.Download />} bottomSeparator="standard" focusable>
				<DialogButton onClick={() => window.location.reload()}>Atualizar</DialogButton>
			</Field>
			<SkyToolsPanel />
		</>
	);
}

const styles = `
.skytools-root{display:flex;flex-direction:column;gap:12px;padding:8px;color:#dfe3ea}
.skytools-header{display:flex;align-items:center;justify-content:space-between;gap:16px}
.skytools-header h2{margin:0;font-size:22px}.skytools-header p{margin:4px 0 0;color:#9aa7b4;font-size:12px}
.skytools-header span{font-size:12px;color:#9fd7ff;text-align:right}
.skytools-tabs{display:flex;flex-wrap:wrap;gap:6px}.skytools-tabs button,.skytools-root button{border:0;border-radius:4px;background:#2b556f;color:#fff;padding:8px 10px;cursor:pointer}
.skytools-tabs button.active{background:#66a6c8;color:#07131b}.skytools-root button:disabled{opacity:.45;cursor:default}
.skytools-row,.skytools-grid{display:grid;grid-template-columns:1fr auto;gap:8px}.skytools-grid{grid-template-columns:1fr 2fr 1fr auto}
.skytools-root input{min-width:0;border:1px solid #405466;border-radius:4px;background:#111922;color:#fff;padding:9px}
.skytools-list{display:flex;flex-direction:column;gap:8px}
.skytools-empty{margin:0;border:1px dashed #405466;border-radius:6px;color:#a7b3bf;padding:12px;text-align:center}
.skytools-game{display:grid;grid-template-columns:92px 1fr auto;gap:10px;align-items:center;background:#111922;border:1px solid #263746;border-radius:6px;padding:8px}
.skytools-game img{width:92px;height:43px;object-fit:cover;border-radius:4px;background:#000}
.skytools-game strong,.skytools-line span{display:block;color:#fff}.skytools-game small,.skytools-line small,.skytools-actions p{display:block;color:#a7b3bf;font-size:12px}
.skytools-line{display:flex;align-items:center;justify-content:space-between;gap:8px;background:#111922;border:1px solid #263746;border-radius:6px;padding:8px}
.skytools-fix{display:flex;flex-direction:column;gap:6px}.skytools-actions{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
`;

export default definePlugin(() => ({
	title: 'SkyTools',
	icon: <IconsModule.Download />,
	content: <SettingsContent />,
}));
