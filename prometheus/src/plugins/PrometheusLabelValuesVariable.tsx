// Copyright The Perses Authors
// Licensed under the Apache License, Version 2.0 (the \"License\");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an \"AS IS\" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import {
  VariablePlugin,
  GetVariableOptionsContext,
  replaceVariables,
  parseVariables,
  datasourceSelectValueToSelector,
  isVariableDatasource,
} from '@perses-dev/plugin-system';
import { DEFAULT_PROM, getPrometheusTimeRange, PROM_DATASOURCE_KIND } from '../model';
import { stringArrayToVariableOptions, PrometheusLabelValuesVariableEditor } from './prometheus-variables';
import { resolvePrometheusDatasource } from './interpolation';
import { PrometheusLabelValuesVariableOptions } from './types';

export const PrometheusLabelValuesVariable: VariablePlugin<PrometheusLabelValuesVariableOptions> = {
  getVariableOptions: async (spec: PrometheusLabelValuesVariableOptions, ctx: GetVariableOptionsContext) => {
    const pluginDef = spec;
    const datasourceSelector =
      datasourceSelectValueToSelector(
        spec.datasource ?? DEFAULT_PROM,
        ctx.variables,
        await ctx.datasourceStore.listDatasourceSelectItems(PROM_DATASOURCE_KIND)
      ) ?? DEFAULT_PROM;
    console.log('🍎 PrometheusLabelValuesVariable: About to resolve datasource with variables:', ctx.variables);
    const { client, requestOptions } = await resolvePrometheusDatasource(
      ctx.datasourceStore,
      datasourceSelector,
      ctx.variables
    );
    console.log('🍎 PrometheusLabelValuesVariable: Resolved requestOptions:', requestOptions);
    const match = pluginDef.matchers ? pluginDef.matchers.map((m) => replaceVariables(m, ctx.variables)) : undefined;

    const timeRange = getPrometheusTimeRange(ctx.timeRange);

    console.log('🍎 PrometheusLabelValuesVariable: ACTUALLY CALLING labelValues with requestOptions:', requestOptions);
    const { data: options } = await client.labelValues(
      {
        labelName: replaceVariables(pluginDef.labelName, ctx.variables),
        'match[]': match,
        ...timeRange,
      },
      requestOptions
    );
    return {
      data: stringArrayToVariableOptions(options),
    };
  },
  dependsOn: (spec: PrometheusLabelValuesVariableOptions, ctx: GetVariableOptionsContext) => {
    const matcherVariables = spec.matchers?.map((m) => parseVariables(m)).flat() || [];
    const labelVariables = parseVariables(spec.labelName);
    const datasourceVariables =
      spec.datasource && isVariableDatasource(spec.datasource) ? parseVariables(spec.datasource) : [];

    // Also check for variables in the datasource configuration itself
    // Since we can't easily access the datasource config here, we'll include 'namespace'
    // as a common variable that might be used in queryParams
    const commonDatasourceVariables = ['namespace'];

    return {
      variables: [...matcherVariables, ...labelVariables, ...datasourceVariables, ...commonDatasourceVariables],
    };
  },
  OptionsEditorComponent: PrometheusLabelValuesVariableEditor,
  createInitialOptions: () => ({ labelName: '' }),
};
